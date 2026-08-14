# 本地通知 设计稿

日期：2026-08-13　状态：已定稿（8/12 讨论 + 8/13 三项决策确认）

## 背景

App 的「提醒」功能在 8/11 因为是假的（只存标记不触发）被删掉（见 CLAUDE.md 产品原则、[[cloud-is-sole-source]] 相关讨论）。这次是把它做成真功能，属于专业化路线第 3 项，留存机制的核心。

## 为什么是本地通知，不是服务器推送

四个场景全部是"排程时就已知时间"的事件（任务日期、心愿期限、胶囊开启日都是本地已有数据），本地通知（系统闹钟触发）完全覆盖，不需要服务器推送那套基建（APNs 证书 + 安卓厂商通道）。

- 零后端成本：不碰云函数/数据库/额度；
- App 被杀也能弹，接收体验等同短信；
- 唯一短板：排程依赖用户打开 App 续订，超过 14 天不打开会枯竭——用沉睡唤回场景部分缓解，不做服务器推送来彻底解决（成本远大于当前收益）。

## 架构

新增 `frontend/lib/notifications.dart`，拆两层职责：

- **`computeNotifications(tasks, wishes, letters, now) -> List<PlannedNotification>`**：纯函数，只读四类本地数据算出「该排哪些通知」，不碰任何插件 API。可脱离设备完整单测。
- **`NotificationScheduler`**：执行层，调用 `flutter_local_notifications` 把 `computeNotifications` 的结果转成实际的取消+重排调用；负责权限申请、设置开关读取。

依赖新增：`flutter_local_notifications`、`timezone`（`zonedSchedule` 必需）。

## 四个场景

| 场景 | 数据源 | 触发条件 | 时间 | 文案模板 |
|---|---|---|---|---|
| 任务到期 | `Task.day` | 当天有 `done=false` 的任务；**同一天全部任务合并成一条** | 9:00 | 1 条时：「{title}」；多条：「今天有 {n} 件事在等你：{title1}、{title2}…」（超 3 条省略号收尾） |
| 心愿期限 | `Wish.targetAt` | 距今 3 天 + 距今 0 天，各排一条（`done=false` 的心愿才排） | 9:00 | 3 天前：「『{title}』还有 3 天到期」；当天：「『{title}』就是今天了」 |
| 胶囊开启 | `Letter.openAt` | 开启日当天 | 10:00 | 「你写给自己的信，今天可以打开了」 |
| 沉睡唤回 | 无（纯时间） | 每次 App 启动时排一条 7 天后的；下次启动先取消旧的再排新的——**任何时刻最多一条待定** | 9:00 | 「你的 {activeWishes.length} 个心愿还在等你」（0 个心愿时不排） |

只排未来 14 天内的事件（心愿期限/胶囊开启超过 14 天的，等用户下次打开 App 且进入 14 天窗口时自然被排上）。

## 排程触发时机

- App 启动完成（`initSession` 之后）；
- 复用 `AppData` 已有的 300ms 防抖（`_scheduleFlush`，任何本地数据改动都会触发它），在其回调末尾追加一次 `NotificationScheduler.rescheduleAll()`——不新增定时器，蹭现成的"数据变了"信号。

## 通知 ID 与幂等

- 任务到期：`hash('task_day_' + dayStr)`——同一天固定一个 ID，天然合并且可重复取消/重排；
- 心愿期限：`hash('wish_3d_' + wishId)` / `hash('wish_due_' + wishId)`；
- 胶囊开启：`hash('letter_' + letterId)`；
- 沉睡唤回：固定 ID（如 `999999`）——每次重排前先取消这个 ID，保证唯一。

`rescheduleAll()` 每次执行：先取消当前受管理的全部 ID（按上述规则重新算出的集合），再排新的一批。不依赖插件的"取消单个不确定 ID"能力，简化实现。

## 权限申请

不在业务入口（设期限/写胶囊/建任务）分别弹窗，改为**挂在排程逻辑本身**：

```
rescheduleAll() 执行时：
  若 (本次算出的通知非空) 且 (SharedPreferences 里没有 notif_permission_asked 标记)：
    调用插件的系统权限请求（iOS: requestPermissions；Android 13+: requestNotificationsPermission）
    无论用户同意与否，写入 notif_permission_asked = true
  若权限已授予：按平常流程排程
  若未授予：跳过实际调度（computeNotifications 仍然算，只是 scheduler 不落地），不重复申请
```

Android 用 `AndroidScheduleMode.inexactAllowWhileIdle`，避免触发 `SCHEDULE_EXACT_ALARM` 权限申请流程。

## 设置页

「我的」页新增一行「通知提醒」（参考 `frontend/lib/tabs/me_tab.dart` 现有行样式），进入 `NotificationSettingsPage`：

- 总开关（`notif_enabled`，默认 true）：关闭时 `rescheduleAll()` 直接取消所有已排通知并返回；
- 四个分开关（`notif_tasks` / `notif_wishes` / `notif_letters` / `notif_dormant`，默认全 true）：`computeNotifications` 按开关过滤对应类别。

存储：`SharedPreferences`，键名如上。

## 通知点击行为

打开 App 到默认首页（心愿清单 tab）即可，不做深链到具体条目——四个场景里"心愿清单"本来就是最相关的落点，做深链是 YAGNI。

## 数据流验证点（testing）

- `computeNotifications` 纯函数单测覆盖：单任务/多任务合并文案、心愿 3 天前+当天两条、心愿已完成不排、胶囊到期当天排、胶囊未到不排、14 天窗口边界、沉睡唤回固定 ID 覆盖旧的；
- 插件调用层（真机验证，iOS + Android 各一次）：权限弹窗只出现一次、通知按时到达、App 被杀后仍到达、设置页关闭对应类别后不再排程。

## 明确不做（YAGNI）

- 打卡挽留提醒（当晚未打卡）——骚扰感强，8/12 已决定观望；
- 通知内容动态刷新（排程后用户改了数据，已发出的通知文案不会变）——影响面小，接受；
- 深链到具体条目——打开首页即可；
- 服务器推送——当前规模不需要，见"背景"。

## 依赖 App 版本

需要发布新版本才对用户生效（本地通知需要客户端代码支持）。
