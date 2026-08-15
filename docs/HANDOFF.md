# 交接/续点文档（2026-08-12 晚）

> 给下一台电脑上的 Claude：读完这份就能无缝接着干，不要重做已完成的部分。

## 项目：管理端（三阶段）

设计稿：`docs/superpowers/specs/2026-08-11-admin-console-design.md`（需求真相）
界面原型：https://claude.ai/code/artifact/e9bb10c3-f630-48eb-9a0c-d515bf25a7b5 （v19 定稿）

### 阶段状态

| 阶段 | 计划文件 | 状态 |
|---|---|---|
| A 后端管理 API | `docs/superpowers/plans/2026-08-11-admin-backend.md` | ✅ 全部 9 任务完成，已部署生产，已合并 main |
| B 管理端前端 | `docs/superpowers/plans/2026-08-12-admin-web.md` | ✅ 全部 8 任务完成（2026-08-12），已部署静态托管：https://renshengqingdan-d8feva5q55d12bab-1258070735.tcloudbaseapp.com ；CORS 已收紧到该域名；100 个 demo_seed 假用户已打 isDemo 标（统计口径 132→32 真实用户） |
| C App 端配套 | `docs/superpowers/plans/2026-08-12-admin-app.md` | ✅ 完成（2026-08-12）：公告横幅/强更/设备上报/埋点/封禁文案，安卓模拟器实测通过，已随 push 发版。内容表数据（预设清单/景点/海报等）App 仍用内置兜底，远程接管留待有真实需求时逐表做 |

### 恢复方法

三阶段全部完成。管理端本地开发：`cd admin && npm run dev`（走 vite 代理）；部署：`npm run deploy`。
本地通知（第 3 项）已完成。第 2 项（崩溃监控）用户暂缓，跳过做了第 3 项；下一步走第 4 项：增量拉取+缓存 → 稳定性测试 → 合规上架。

### 计划 A 遗留事项（前端/App 阶段处理）

- 性能红旗：`allLogins/allEvents` 无分页，破千条后 stats 统计静默失真；logins/events 无清理机制；用户过千后 /admin/users 与 stats 截断。
- /admin/quota 的 limit 字段 API 不返回（恒 null），前端按"只显示用量"处理。
- 演示用户编辑是**全量回填**语义（非增量 patch），前端表单必须回填全部字段。
- announcements 的 startAt/endAt 是毫秒时间戳。
- /config 挂在用户 JWT 路由下——未登录 App 拿不到公告/minVersion，App 端实现注意。
- 管理端上线后：把后端 CORS 从 * 收紧到静态托管域名（计划 B Task 8 已含）。

### ⚠️ 换电脑必带的 gitignored 文件（含密钥，不进 git，自己安全拷贝）

- `backend/cloudbaserc.json` —— 含 **JWT_SECRET**（换了会把全体用户登出！2026-08-11 已踩过一次）、**ADMIN_KEY**（管理端登录密钥）、CLOUDBASE_ENV_ID。**没有它绝对不要在新电脑上执行 `npm run deploy`**。
- 可选：`.claude/settings.local.json`（权限偏好 bypassPermissions，重建也行）。

### 其他挂起事项

- 腾讯云 API 密钥（TC_SECRET_ID/TC_SECRET_KEY）未配置——配到 cloudbaserc.json 后重新部署，额度监控才有数据。
- **⚠️ 待办：腾讯位置服务要做实名认证，否则地点搜索用不了。** 管理端选点地图 2026-08-15 从高德换成腾讯地图，`TMAP_KEY` 已申请并配好部署（key 在 cloudbaserc.json，gitignored）。当天实测：
  - 逆地理编码（`/ws/geocoder/v1/`）正常——点地图选点、自动回填省份都能用；
  - **地点搜索（`/ws/place/v1/search`）返回 `status:121「此key每日调用量已达到上限」**——未实名认证的个人开发者这个 API 免费额度极少，几次调用就用完。**解决办法：去 lbs.qq.com 控制台做实名认证提额**（额度每天重置，会自动恢复一点点，但不认证始终不够用）。
  - 交互差异：腾讯 `MultiMarker` 官方文档没有拖拽标记能力（高德 `Marker` 有 `draggable`），所以选点改成「点地图放标记」+ 手填经纬度微调，不做拖拽。
  - 没配 key 时 `mapConfig` 返回 `available:false`，管理端退化成手填经纬度，不影响其它功能。
- 用户手机/模拟器因 2026-08-11 JWT 密钥轮换需重新登录一次。
- 上线前待办：恢复本地缓存+增量拉取（见 CLAUDE.md 产品原则与 specs 里的记录）——「云为权威 + 缓存加速 + 失败明示」三件套。

## 专业化路线（2026-08-12 评估，按顺序执行）

1. ~~管理端收尾（计划 B Task 2-8 → 计划 C）~~ ✅ 2026-08-12 完成
2. 崩溃监控——**2026-08-15 重新评估后决定暂不做**（用户拍板）。⚠️ 之前写的「接腾讯 Bugly（免费，约半天）」这个判断是**错的**，别再照着做，核实结果：
   - **Bugly 专业版**（bugly.tds.qq.com，有官方 Flutter SDK `bugly_pro_flutter`）**是收费的**，无免费额度无试用，起步价 3.2 万/年（6 亿条上报）或月活套餐 5 万/年（5 万 MAU），不退款。对本项目（真实用户 32 个）完全不现实。
   - **Bugly QQ 版**（bugly.qq.com）免费，但**没有官方 Flutter SDK**，只有社区插件 `flutter_bugly`（71 likes、7 个月未更新、上传者未认证）。
   - **Sentry 官方云服务不可用**：sentry.io 国内访问受限，上报大概率失败；且崩溃数据传境外服务器涉及数据出境，会给 App 备案和国内商店上架增加合规成本。
   - **将来真要做，推荐路线**：自托管 **GlitchTip**（开源、Sentry API 兼容——可直接用 Sentry 官方 Flutter SDK 只改 DSN、1GB 内存就能跑、事件数不限），服务器自己控制，合规和国内访问都干净。需要原生崩溃采集再加 xCrash（Android）/ KSCrash（iOS，腾讯自家 Matrix 也是用它）。
   - 或退一步做**极简自研**：Dart 层异常（`FlutterError.onError` / `PlatformDispatcher.onError`）落本地 → 下次启动补发到自己的 CloudBase 接口；再加「启动写标记、正常退出清除」检测异常退出。能答「有没有在崩/多不多/哪个版本/什么机型」，但拿不到原生崩溃堆栈。
   - **建议时机**：放量推广前再补。现在用户量小，崩溃更可能靠用户直接反馈发现。
3. ~~本地通知做成真功能：flutter_local_notifications，场景=任务到期提醒 + 时光胶囊开启日 + 心愿期限 + 沉睡唤回（留存命脉）~~ ✅ 2026-08-15 完成
4. 增量拉取+缓存恢复（已有待办，「云为权威+缓存加速+失败明示」三件套，约半天）← **下一步从这开始**
5. ~~一轮系统性稳定测试：弱网 / 杀进程恢复 / 低端机 / 平板~~ ✅ 2026-08-15 完成（iOS+Android 模拟器实测：断网时同步失败横幅正常亮起、恢复后重试成功；编辑数据中途强杀重启数据不丢不错乱；768MB 单核低配模拟器跑通 51 条长列表无崩溃无 ANR；iPad 无溢出报错，顺带发现并修复了平板卡片布局问题）
6. 合规与上架（流程周期长，尽早启动并行走）：隐私政策+用户协议页 → App 备案 → 安卓软著 → 上架华为/小米/App Store
