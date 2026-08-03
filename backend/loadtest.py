#!/usr/bin/env python3
"""压测 / 额度标定：模拟 N 个用户的真实使用，量出每人每月要花多少资源点。

跑法：
    python3 loadtest.py --users 20            # 打线上（会真花额度）
    python3 loadtest.py --users 5 --concurrency 5   # 看并发下的延迟

它做的事，和 App 里真实发生的一一对应：
    注册         → register + 全量 pull + 播 50 条心愿并推送（客户端按 80KB 分块）
    每天开 App   → 增量 pull（默认一天 3 次）
    每天改东西   → push 若干条改动
    收尾         → 注销账号，不留垃圾数据

跑完对着 CloudBase 控制台的资源点消耗对一下，就是真实成本。
脚本自己也会按官方换算（读/写 200点/万次、云函数调用 13.3点/万次）估一份，
两边差得多说明有没算到的开销（多半是索引没命中导致的全表扫）。
"""
import argparse, json, statistics, time, urllib.error, urllib.request
from concurrent.futures import ThreadPoolExecutor

BASE = ("https://renshengqingdan-d8feva5q55d12bab-1258070735"
        ".ap-shanghai.app.tcloudbase.com/api")

# 官方换算：1 元 = 1000 资源点
PT_PER_READ = 200 / 10000
PT_PER_WRITE = 200 / 10000
PT_PER_INVOKE = 13.3 / 10000

lat: dict[str, list[float]] = {}
ops = {"read": 0, "write": 0, "invoke": 0}


def call(method, path, token=None, body=None, tag=None):
    req = urllib.request.Request(
        BASE + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"content-type": "application/json",
                 **({"authorization": f"Bearer {token}"} if token else {})})
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            out = json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        out = {"error": f"http_{e.code}"}
    lat.setdefault(tag or path, []).append(time.perf_counter() - t0)
    ops["invoke"] += 1
    return out


def chunks(items, budget=80 * 1024):
    """照抄客户端的 80KB 分块规则"""
    cur, size = [], 0
    for it in items:
        n = len(json.dumps(it, ensure_ascii=False).encode())
        if cur and size + n > budget:
            yield cur
            cur, size = [], 0
        cur.append(it)
        size += n
    if cur:
        yield cur


def wish(i, uid, updated):
    return {"_id": f"w-{uid}-{i}", "title": f"心愿 {i}", "color": "A8B8F8",
            "createdAt": 1720000000000, "updatedAt": updated}


def one_user(n, launches, edits, days):
    """跑完一个用户的「注册 + N 天使用」，返回它产生的数据库操作数"""
    uid = f"lt{int(time.time() * 1000)}{n}"
    read = write = 0

    r = call("POST", "/auth/register", body={"account": uid, "password": "pw123456"},
             tag="register")
    token = r.get("token")
    if not token:
        print(f"  ⚠️  {uid} 注册失败: {r}")
        return 0, 0
    read += 1   # getUserByAccount
    write += 1  # createUser

    # 注册后全量拉一次（新账号，云端是空的）
    call("GET", "/sync/pull?since=0", token, tag="pull_full")
    read += 1   # profile

    # 播 50 条并推送
    seeds = [wish(i, uid, int(time.time() * 1000)) for i in range(50)]
    for c in chunks(seeds):
        call("POST", "/sync/push", token, {"wishes": c}, tag="push_seed")
        read += len(c)   # 批量查存在性
        write += len(c)
    since = int(time.time() * 1000)

    for _ in range(days):
        for _ in range(launches):
            r = call("GET", f"/sync/pull?since={since}", token, tag="pull_inc")
            read += 1 + len(r.get("wishes", []))  # profile + 变化的记录
        changed = [wish(i, uid, int(time.time() * 1000)) for i in range(edits)]
        call("POST", "/sync/push", token, {"wishes": changed}, tag="push_edit")
        read += edits
        write += edits
        since = int(time.time() * 1000)

    call("DELETE", "/auth/account", token, tag="delete")
    write += 1
    ops["read"] += read
    ops["write"] += write
    return read, write


def pct(xs, p):
    return sorted(xs)[min(len(xs) - 1, int(len(xs) * p))]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--users", type=int, default=10)
    ap.add_argument("--concurrency", type=int, default=4)
    ap.add_argument("--launches", type=int, default=3, help="每天开几次 App")
    ap.add_argument("--edits", type=int, default=10, help="每天改几条")
    ap.add_argument("--days", type=int, default=1, help="模拟几天（成本按天线性外推）")
    a = ap.parse_args()

    print(f"开始：{a.users} 个用户 × {a.days} 天"
          f"（每天 {a.launches} 次启动 + {a.edits} 条改动），并发 {a.concurrency}")
    print(f"开始时间 {time.strftime('%H:%M:%S')} —— 记下来，跑完去控制台对这段的消耗\n")

    t0 = time.perf_counter()
    with ThreadPoolExecutor(max_workers=a.concurrency) as ex:
        list(ex.map(lambda i: one_user(i, a.launches, a.edits, a.days),
                    range(a.users)))
    wall = time.perf_counter() - t0

    print(f"\n结束时间 {time.strftime('%H:%M:%S')}，总耗时 {wall:.1f}s\n")
    print("延迟（秒）")
    print(f"{'接口':<12}{'次数':>6}{'p50':>8}{'p95':>8}{'max':>8}")
    for k, v in sorted(lat.items()):
        print(f"{k:<12}{len(v):>6}{pct(v,.5):>8.2f}{pct(v,.95):>8.2f}{max(v):>8.2f}")

    pts = (ops["read"] * PT_PER_READ + ops["write"] * PT_PER_WRITE
           + ops["invoke"] * PT_PER_INVOKE)
    per_user = pts / a.users
    signup = per_user  # days=1 时，注册开销和一天使用混在一起，下面拆开算
    print(f"\n数据库操作：读 {ops['read']}、写 {ops['write']}、云函数调用 {ops['invoke']}")
    print(f"估算消耗：{pts:.1f} 点，人均 {per_user:.2f} 点"
          f"（含一次性的注册 + 播 50 条）")

    # 注册一次性成本：1 读 1 写 + 50 读 50 写 + 1 读 ≈ 102 次操作
    once = 102 * PT_PER_READ
    daily = max(per_user - once, 0) / max(a.days, 1)
    print(f"  其中一次性注册 ≈ {once:.2f} 点，日常 ≈ {daily:.2f} 点/人/天")
    if daily > 0:
        print(f"\n按 3000 点/月推算：月成本 {daily*30:.1f} 点/人 → "
              f"约 {int(3000/(daily*30))} 个日活顶满额度")
    print("\n⚠️ 以上是脚本按官方换算估的。真实数字以控制台「资源点消耗」为准，"
          "两边差很多的话多半是索引没建对。")


if __name__ == "__main__":
    main()
