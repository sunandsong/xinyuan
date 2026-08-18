#!/usr/bin/env python3
"""把提审用的测试账号填满，让审核员每个功能都能点到。

为什么需要这个脚本：应用商店驳回里有一类是「无法评估功能」——审核员拿测试账号登进去，
任务页空的、时光胶囊 0 封、地图一个点都没亮，就会认为这些功能不存在或者不能用。
所以提审账号不能只是「能登录」，得每条功能路径上都有看得见的数据。

**重跑安全**：所有记录用固定 _id（rev_t_* / rev_l_*），重跑是覆盖不是新增。
任务日期按「运行当天」相对计算，所以**提审前重跑一次**，日历上才会有「今天的安排」，
否则隔几周再看就只剩历史记录了。

    python3 scripts/seed_review_account.py

写的是**生产库**里的真实账号，不是沙箱。
"""
import json, time, urllib.request

BASE = "https://renshengqingdan-d8feva5q55d12bab-1258070735.ap-shanghai.app.tcloudbase.com/api"
ACCOUNT, PASSWORD = "stabtest02", "test123456"

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
    "marathon": ("w_mst4x6811svskz", "A8B8F8"),  # 完成一次半程马拉松
    "run5k":    ("w_mst4x6811r75jz", "B8E0C8"),  # 跑完一次五公里
    "lang":     ("w_mst4x6841t6nu7", "A8B8F8"),  # 学一门外语到能对话
    "letter":   ("w_mst4x6871uyq75", "F5D08C"),  # 写一封信给十年后的自己
    "plant":    ("w_mst4x6891vqt9q", "F09A9A"),  # 种一盆植物并养活它
}

# 过去几天有已完成的（日历能看到成果），今天有待办的（进去就有事可做），
# 未来几天也有（能演示往后翻）
PLAN = [
    (-3, "跑步 3 公里", "run5k", True),
    (-2, "背 30 个单词", "lang", True),
    (-1, "跑步 4 公里", "run5k", True),
    (-1, "给绿萝换盆", "plant", True),
    (0,  "跑步 5 公里", "run5k", False),
    (0,  "听力练习 20 分钟", "lang", False),
    (0,  "给十年后的自己写提纲", "letter", False),
    (1,  "半马训练：长距离慢跑", "marathon", False),
    (3,  "报名一场线上半马", "marathon", False),
]

tasks = []
for i, (off, title, wk, done) in enumerate(PLAN):
    wid, color = W[wk]
    tasks.append({
        "_id": f"rev_t_{i+1}", "title": title, "day": day(off), "done": done,
        "wishId": wid, "color": color, "desc": None,
        "createdAt": now - DAY * 5, "updatedAt": now, "deleted": False,
    })

# 一封已到期能开、一封还锁着——两种状态都要有，否则演示不出「时间到了才能拆」这个卖点
letters = [
    {"_id": "rev_l_1", "title": "写给一年前的自己",
     "content": "那时候你觉得跑五公里是天方夜谭，现在你在准备半马了。\n慢一点没关系，别停就行。",
     "openAt": now - DAY * 2, "createdAt": now - DAY * 370, "updatedAt": now, "deleted": False},
    {"_id": "rev_l_2", "title": "写给十年后的自己",
     "content": "希望你还留着这份清单，也希望上面的事你大都做过了。\n如果没有也没关系，至少你认真想过要怎么活。",
     "openAt": now + DAY * 3650, "createdAt": now - DAY * 10, "updatedAt": now, "deleted": False},
]

accepted = api("/sync/push", {"tasks": tasks, "letters": letters}, "POST", token)["accepted"]

# 打卡点挑得南北东西都有，地图缩到全国也看得出点亮了几处
spots = {"故宫": now - DAY * 400, "西湖": now - DAY * 300, "黄山": now - DAY * 200,
         "鼓浪屿": now - DAY * 150, "泰山": now - DAY * 90, "九寨沟": now - DAY * 30}
profile = api("/me", {
    "gender": "男", "birthday": "1995-06-18", "avatarEmoji": "🌱",
    "checkins": spots, "placeCount": len(spots),
}, "PATCH", token)["profile"]

pulled = api("/sync/pull?since=0", token=token)
alive = lambda xs: [x for x in xs if not x.get("deleted")]
ws, ts, ls = alive(pulled["wishes"]), alive(pulled["tasks"]), alive(pulled["letters"])
today = day(0)

print(f"账号      : {ACCOUNT} / {PASSWORD}")
print(f"心愿      : {len(ws)} 条（已实现 {sum(1 for w in ws if w.get('done'))} 条）")
print(f"任务      : {len(ts)} 条（今天 {sum(1 for t in ts if t.get('day') == today)} 条待办）")
print(f"时光胶囊  : {len(ls)} 封（可开启 {sum(1 for l in ls if l.get('openAt', 0) <= now)} 封）")
print(f"地图打卡  : {len(profile.get('checkins') or {})} 处")
print(f"成就勋章  : {len(profile.get('achievements') or {})} 枚")
print(f"本次写入  : {accepted}")
