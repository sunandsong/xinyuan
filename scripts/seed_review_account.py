#!/usr/bin/env python3
"""把提审用的测试账号填满，让审核员每个功能都能点到。

为什么需要这个脚本：应用商店驳回里有一类是「无法评估功能」——审核员拿测试账号登进去，
任务页空的、时光胶囊 0 封、地图一个点都没亮，就会认为这些功能不存在或者不能用。
所以提审账号不能只是「能登录」，得每条功能路径上都有看得见的数据。

**关键设计：任务铺满一整个日期带（见 PAST_DAYS / FUTURE_DAYS），不是只排今天。**
提交之后哪天送到审核员手上是不受控的，可能隔一天也可能隔一周，还可能被驳回后二审。
如果按「跑脚本那天」排任务，隔几天再看日历上今天就是空的——等于白填。
铺成日期带之后，窗口内任意一天登进去都有：往前的完成记录、今天的待办、往后的安排。

**重跑安全**：任务 _id 由日期偏移算出来，重跑是覆盖不是新增；上一轮留下的、这一轮
不再需要的任务会被自动打删除标记，不会越积越多。

    python3 scripts/seed_review_account.py

写的是**生产库**里的真实账号，不是沙箱。
"""
import json, time, urllib.request

BASE = "https://renshengqingdan-d8feva5q55d12bab-1258070735.ap-shanghai.app.tcloudbase.com/api"
ACCOUNT, PASSWORD = "stabtest02", "test123456"

# 日期带宽度。往前是「已经用了一阵子」的观感；往后要盖住的是**提交到审核之间的不确定等待**——
# 大部分商店 1~7 天，加上驳回改完二审，三个月足够兜住，不必再盯着日期重跑。
# 往后不能无限拉长：脚本只能把跑之前的日子标成已完成（标未来是「已完成」等于数据错乱），
# 所以带子越长，真到那天回头看，中间那段空窗越像个断更用户。90 天是这两头的折中。
PAST_DAYS, FUTURE_DAYS = 45, 90

DAY = 86_400_000
now = int(time.time() * 1000)


def day(offset: int) -> str:
    t = time.localtime((now + offset * DAY) / 1000)
    return f"{t.tm_year:04d}-{t.tm_mon:02d}-{t.tm_mday:02d}"


def api(path, body=None, method="GET", token=None):
    headers = {"content-type": "application/json"}
    if token:
        headers["authorization"] = "Bearer " + token
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
    return json.load(urllib.request.urlopen(req))


token = api("/auth/login", {"account": ACCOUNT, "password": PASSWORD}, "POST")["token"]

# 任务挂在真实心愿上，wishId 决定日历上圆点的颜色；没有 wishId 的任务日历里是灰的。
# 这几个 id 来自该账号自带的预置心愿，换账号要重新取。
W = {
    "run5k":    ("w_mst4x6811r75jz", "B8E0C8"),  # 跑完一次五公里
    "marathon": ("w_mst4x6811svskz", "A8B8F8"),  # 完成一次半程马拉松
    "lang":     ("w_mst4x6841t6nu7", "A8B8F8"),  # 学一门外语到能对话
    "plant":    ("w_mst4x6891vqt9q", "F09A9A"),  # 种一盆植物并养活它
    "letter":   ("w_mst4x6871uyq75", "F5D08C"),  # 写一封信给十年后的自己
}

# 每天从这里挑，按天序轮换。都是能跟上面心愿对上的日常动作，
# 不用随机数——重跑要生成一模一样的内容，否则同一个 _id 的标题会来回变。
POOL = [
    ("run5k",    "跑步 3 公里"),
    ("lang",     "背 30 个单词"),
    ("plant",    "给绿萝浇水"),
    ("run5k",    "跑步 5 公里"),
    ("lang",     "听力练习 20 分钟"),
    ("marathon", "半马训练：长距离慢跑"),
    ("plant",    "记录一次植物长势"),
    ("lang",     "跟读一段外语播客"),
    ("run5k",    "跑步 4 公里"),
    ("letter",   "给十年后的自己写点东西"),
]

tasks, wanted_ids = [], set()
for off in range(-PAST_DAYS, FUTURE_DAYS + 1):
    # **每一天都必须有任务**。原来这里每周留一天空着图个真实，模拟了一下发现
    # 审核员有 1/7 的概率正好撞在那天，打开就是「今天没有安排」——
    # 拟真度换不来这个风险，改成靠条数多少来体现忙闲，最少也得有一条。
    # 今天排 3 条：审核员打开就落在今天，这天内容最要紧。
    count = 3 if off == 0 else (2 if off % 3 else 1)
    for i in range(count):
        wk, title = POOL[(off * 2 + i) % len(POOL)]
        wid, color = W[wk]
        # _id 由偏移算出来，所以同一天的任务重跑时是覆盖。用 d{偏移+1000} 避免负号
        tid = f"rev_t_d{off + 1000}_{i}"
        wanted_ids.add(tid)
        tasks.append({
            "_id": tid, "title": title, "day": day(off),
            # 跑脚本时点之前的算已完成，之后的算待办。
            # 之后随着时间推移，「今天」会往前漂，漂过的那几天会显示成没做完——
            # 这看着就是个偶尔断更的真实用户，不影响演示，比未来任务被标成"已完成"自然得多
            "done": off < 0,
            "wishId": wid, "color": color, "desc": None,
            "createdAt": now - DAY * (PAST_DAYS + 5), "updatedAt": now, "deleted": False,
        })

# 上一轮铺的、这一轮日期带里不再包含的任务，打上删除标记收掉，
# 否则反复重跑会在库里越堆越多（第一版用的是 rev_t_1..9 那套 id，也在这里被收掉）
existing = api("/sync/pull?since=0", token=token)["tasks"]
stale = [t["_id"] for t in existing
         if t["_id"].startswith("rev_t_") and t["_id"] not in wanted_ids and not t.get("deleted")]
for tid in stale:
    tasks.append({"_id": tid, "deleted": True, "updatedAt": now})

# 一封已到期能开、一封还锁着——两种状态都要有，否则演示不出「时间到了才能拆」这个卖点。
# 用相对时间也没问题：已到期的只会更过期，锁着的锁到十年后
letters = [
    {"_id": "rev_l_1", "title": "写给一年前的自己",
     "content": "那时候你觉得跑五公里是天方夜谭，现在你在准备半马了。\n慢一点没关系，别停就行。",
     "openAt": now - DAY * 2, "createdAt": now - DAY * 370, "updatedAt": now, "deleted": False},
    {"_id": "rev_l_2", "title": "写给十年后的自己",
     "content": "希望你还留着这份清单，也希望上面的事你大都做过了。\n如果没有也没关系，至少你认真想过要怎么活。",
     "openAt": now + DAY * 3650, "createdAt": now - DAY * 10, "updatedAt": now, "deleted": False},
]

accepted = api("/sync/push", {"tasks": tasks, "letters": letters}, "POST", token)["accepted"]

def upload_avatar() -> str:
    """生成一张头像图并直传云存储，返回可访问的 URL。

    走的是 App 自己的两步直传：先找后端换一次性凭证（云函数网关请求体只有约 100KB，
    图片本体过不去），再把字节 PUT 给云存储。
    """
    from io import BytesIO
    from PIL import Image, ImageDraw

    size = 256
    img = Image.new("RGB", (size, size), (74, 158, 120))  # 跟 App 主题绿一个色系
    d = ImageDraw.Draw(img)
    # 画一株简笔小苗：一根茎两片叶。不用字体，免得机器上没有中文字体渲染出方块
    d.line([(128, 200), (128, 110)], fill=(240, 248, 243), width=9)
    d.ellipse([60, 96, 128, 140], fill=(240, 248, 243))
    d.ellipse([128, 118, 196, 162], fill=(214, 234, 222))
    buf = BytesIO()
    img.save(buf, format="PNG")
    data = buf.getvalue()

    t = api("/upload", {"mime": "image/png"}, "POST", token)
    put = urllib.request.Request(t["url"], data=data, method="PUT",
                                 headers={**t.get("headers", {}), "content-type": "image/png"})
    urllib.request.urlopen(put)
    return t["downloadUrl"]


avatar_url = upload_avatar()

# 打卡点挑得南北东西都有，地图缩到全国也看得出点亮了几处
spots = {"故宫": now - DAY * 400, "西湖": now - DAY * 300, "黄山": now - DAY * 200,
         "鼓浪屿": now - DAY * 150, "泰山": now - DAY * 90, "九寨沟": now - DAY * 30}
profile = api("/me", {
    "gender": "男", "birthday": "1995-06-18",
    # 注意别在这里写 avatarEmoji：后端 pickProfilePatch 收这个字段，但**前端一处都没用**，
    # 设了等于没设（实测过，「我的」页还是默认灰头像）。头像走 avatarUrl，见下面 upload_avatar()
    "avatarUrl": avatar_url,
    "checkins": spots, "placeCount": len(spots),
    # 不上榜。这账号的数据是脚本填的，已完成任务比榜首真人还多（实测 75 vs 44），
    # 不挡掉它一登录就双榜第一——一个测试账号霸榜正是「虚假繁荣」那个审核风险点本身。
    # 审核期排行榜整个是关的，挡掉不影响演示；真要演示这个开关，
    # App 里「我的 → 不参与排行榜」自己能点。
    "hideFromRank": True,
}, "PATCH", token)["profile"]

pulled = api("/sync/pull?since=0", token=token)
alive = lambda xs: [x for x in xs if not x.get("deleted")]
ws, ts, ls = alive(pulled["wishes"]), alive(pulled["tasks"]), alive(pulled["letters"])
days = sorted({t["day"] for t in ts})

print(f"账号      : {ACCOUNT} / {PASSWORD}")
print(f"心愿      : {len(ws)} 条（已实现 {sum(1 for w in ws if w.get('done'))} 条）")
print(f"任务      : {len(ts)} 条，覆盖 {len(days)} 天 {days[0]} ~ {days[-1]}")
print(f"            （已完成 {sum(1 for t in ts if t.get('done'))} 条；今天 {sum(1 for t in ts if t['day'] == day(0))} 条）")
if stale:
    print(f"            清掉上一轮遗留 {len(stale)} 条")
print(f"时光胶囊  : {len(ls)} 封（可开启 {sum(1 for l in ls if l.get('openAt', 0) <= now)} 封）")
print(f"地图打卡  : {len(profile.get('checkins') or {})} 处")
print(f"头像      : {'已上传' if profile.get('avatarUrl') else '⚠️ 没有'}")
print(f"成就勋章  : {len(profile.get('achievements') or {})} 枚")
print(f"排行榜    : {'已挡掉，不污染真实榜单' if profile.get('hideFromRank') else '⚠️ 参与中'}")
print(f"本次写入  : {accepted}")
