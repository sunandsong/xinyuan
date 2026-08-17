# 交接/续点文档（最后更新 2026-08-16）

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
专业化路线第 1/2/3/5 项已完成（管理端、崩溃监控、本地通知、稳定性测试）。**下一步走第 4 项：增量拉取+缓存恢复**，之后是第 6 项合规上架。

> ✅ **发版流水线已彻底修好（2026-08-17）**：不只是止血锁版本，Gradle→8.14、
> AGP→8.11.1、Kotlin→2.2.20 已经升级到位，`flutter-version` 已解锁到验证过的
> 3.47.0（本地分别用 3.44.8 和 3.47.0 两个版本打包+装模拟器跑起来都验证过）。
> b10~b21 积压的功能（本地通知/平板修复/腾讯地图/崩溃监控/图片远程化）都已经
> 发出去了。以后 Flutter 出新版不用再靠这套 Gradle/AGP/Kotlin 兜底太久——它们
> 自己也快到"即将不支持"的边界了（Gradle 9.1+/AGP 9.0+/Kotlin 2.3.20+），
> 下次升级同样得走"本地多版本验证过再改 CI"这个流程，不能直接改 yml 里的版本号。

### 计划 A 遗留事项（前端/App 阶段处理）

- 性能红旗：`allLogins/allEvents` 无分页，破千条后 stats 统计静默失真；logins/events 无清理机制；用户过千后 /admin/users 与 stats 截断。
- /admin/quota 的 limit 字段 API 不返回（恒 null），前端按"只显示用量"处理。
- 演示用户编辑是**全量回填**语义（非增量 patch），前端表单必须回填全部字段。
- announcements 的 startAt/endAt 是毫秒时间戳。
- /config 挂在用户 JWT 路由下——未登录 App 拿不到公告/minVersion，App 端实现注意。
- 管理端上线后：把后端 CORS 从 * 收紧到静态托管域名（计划 B Task 8 已含）。

### ⚠️ 换电脑必带的 gitignored 文件（含密钥，不进 git，自己安全拷贝）

- `backend/cloudbaserc.json` —— **没有它绝对不要在新电脑上执行 `npm run deploy`**（会用空密钥覆盖线上配置）。里面 7 个 envVariables：
  - **JWT_SECRET** —— 换了会把全体用户登出！2026-08-11 已踩过一次
  - **ADMIN_KEY** —— 管理端登录密钥
  - **TMAP_KEY** —— 腾讯位置服务（管理端选点地图 + 逆地理编码）
  - **TC_SECRET_ID / TC_SECRET_KEY** —— 腾讯云 API（额度监控）
  - MODE / CLOUDBASE_ENV_ID —— 非密钥，丢了也能照着仓库补
  拷过去之后 `python3 -c "import json;print(list(json.load(open('backend/cloudbaserc.json'))['functions'][0]['envVariables']))"` 核对一下有没有少。
- 可选：`.claude/settings.local.json`（权限偏好 bypassPermissions，重建也行）。

### 其他挂起事项

- **⚠️ 待办：腾讯位置服务要做实名认证，否则地点搜索用不了。** 管理端选点地图 2026-08-15 从高德换成腾讯地图，`TMAP_KEY` 已申请并配好部署（key 在 cloudbaserc.json，gitignored）。当天实测：
  - 逆地理编码（`/ws/geocoder/v1/`）正常——点地图选点、自动回填省份都能用；
  - **地点搜索（`/ws/place/v1/search`）返回 `status:121「此key每日调用量已达到上限」**——未实名认证的个人开发者这个 API 免费额度极少，几次调用就用完。**解决办法：去 lbs.qq.com 控制台做实名认证提额**（额度每天重置，会自动恢复一点点，但不认证始终不够用）。
  - 交互差异：腾讯 `MultiMarker` 官方文档没有拖拽标记能力（高德 `Marker` 有 `draggable`），所以选点改成「点地图放标记」+ 手填经纬度微调，不做拖拽。
  - 没配 key 时 `mapConfig` 返回 `available:false`，管理端退化成手填经纬度，不影响其它功能。
- 用户手机/模拟器因 2026-08-11 JWT 密钥轮换需重新登录一次。
- 测试账号 `stabtest02` / `test123456`（稳定性测试时注册的，云端有 12 条已完成心愿，验证分享卡/达成弹窗很方便）。
- 上线前待办：恢复本地缓存+增量拉取（见 CLAUDE.md 产品原则与 specs 里的记录）——「云为权威 + 缓存加速 + 失败明示」三件套。

## 图片资源体系（2026-08-15/16 做完，路线外插入项）

App 里所有展示类图片都能在管理端换了，不用发版。三层结构：

1. **打包兜底**（`frontend/assets/`）—— 保证没网/未登录/首次启动/云挂了都有东西显示，**别为了省体积删掉**
2. **云端下发**（`/config`）—— 运营改图的入口，优先级高于内置图
3. **磁盘缓存**（`frontend/lib/photos.dart` 的 `cachedImageFile`）—— 命中直接读本地文件，不发网络

### 管理端「图片素材」6 张表

| 表 | 用途 | 条数 |
|---|---|---|
| poster_task / poster_wish | 任务/心愿成绩单海报 | 5 / 5 |
| poster_done | 心愿达成弹窗底图 | 4 |
| hero_images | 心愿没照片时的兜底头图 | 5 |
| cover_declare | 宣告卡封面（可左右滑） | 3 |
| cover_done | 凭证卡封面 | 4 |

云存储：`content/posters/`(14) `content/hero/`(9) `content/honor/`(14)。
种子脚本 `backend/scripts/seed-content.ts` + `seed-poster-images.ts` 都已同步，重新播种不会丢。

### 几个容易踩的点（都已踩过并修掉）

- **别把上传路径改成「按用途固定文件名然后覆盖」**。App 按去掉签名的稳定链接做磁盘缓存，
  覆盖同名文件的话 URL 不变 → 缓存永远命中旧图，用户得重装 App。现在 `admin/upload.ts`
  每次生成随机路径是**有意为之**，那里留了警告注释。
- **云存储链接直接 `Image.network` 取不到**（403），必须走 `/photo-urls` 换临时链接，
  统一用 `WishPhoto` 组件，它已经封装好了换链接 + 失败回退。
- **临时链接每次签名都不同**，所以缓存 key 必须用去掉 `?` 后的稳定链接，否则内存/磁盘
  缓存全都命中不了，表现就是每次进页面闪一下。
- **图片分配用 `doneNumberOf(w)` 轮流**，不是 id 哈希取模——哈希不保证均匀，实测 11 条
  分 4 张是 4/4/2/1，用户观感就是「没换」。
- `/config` 在**启动、登录、切回前台**（5 分钟节流）三个时机拉。运营改完图，用户切个
  后台再回来就生效。

## 专业化路线（2026-08-12 评估，按顺序执行）

1. ~~管理端收尾（计划 B Task 2-8 → 计划 C）~~ ✅ 2026-08-12 完成
2. ~~崩溃监控~~ ✅ 2026-08-15 完成（**自研，没接第三方**）。实现见 `frontend/lib/crash_reporter.dart`、`backend/src/handlers/crash.ts`、管理端「崩溃」页。
   - **架构**：崩溃当下**只写本地不发网络**（进程可能马上没了、用户可能没网），下次启动补发，发成功才清。后端按指纹（异常类型 + 堆栈前几帧，剔除地址/数字）聚合，同一 bug 崩一万次归成一条只累加 count。
   - **三层覆盖**：① Dart 层未捕获异常（两端都有，完整可读堆栈）② 原生崩溃（**只有 iOS**，KSCrash 2.6.0）③ 异常退出计数（启动写 alive 标记、正常退后台清除，两端都有）。
   - ⚠️ **Android 的 xCrash 已摘除，别再加回来**：实测它的 `libxcrash.so` LOAD 段 `align=0x1000`（4KB），过不了 Google Play「targetSdk>=35 必须支持 16KB 内存页」的要求（2025-11-01 起，延期至 2026-05-31）——上架硬阻塞，16KB 页真机也加载不了。根因是它停更在 NDK r28 之前。**当时用 4KB 页模拟器测试全过，是模拟器骗人的典型案例**；这类 native 库合规问题必须直接查构建产物（`llvm-readelf -l xxx.so` 看 LOAD align）。
   - 替代品都查过没有更好的：Tencent/matrix 停更在 2024-07 更旧；sentry-java 虽活跃但 native 崩溃产出 minidump，必须配 Sentry symbolicator 服务端才能读。
   - **未做符号化**：拿到的是未符号化地址堆栈，看得出崩在哪个库/多少次/什么机型版本，读不出具体哪一行。要那个得按版本归档 dSYM 并在服务端跑 atos——CloudBase 云函数跑不了原生工具，需单独机器。真有高频崩溃要定位时，手工对那一个版本符号化即可，不必建全自动流水线。
   - 曾评估过的第三方（结论仍有效，别重复评估）：**Bugly 专业版收费**（无免费额度，起步 3.2 万/年）；Bugly QQ 版免费但无官方 Flutter SDK；**sentry.io 国内访问受限**且数据出境影响备案上架。将来真要上第三方，推荐自托管 GlitchTip（Sentry API 兼容，可复用官方 SDK 只改 DSN）。
3. ~~本地通知做成真功能：flutter_local_notifications，场景=任务到期提醒 + 时光胶囊开启日 + 心愿期限 + 沉睡唤回（留存命脉）~~ ✅ 2026-08-15 完成
4. 增量拉取+缓存恢复（已有待办，「云为权威+缓存加速+失败明示」三件套，约半天）← **下一步从这开始**
5. ~~一轮系统性稳定测试：弱网 / 杀进程恢复 / 低端机 / 平板~~ ✅ 2026-08-15 完成（iOS+Android 模拟器实测：断网时同步失败横幅正常亮起、恢复后重试成功；编辑数据中途强杀重启数据不丢不错乱；768MB 单核低配模拟器跑通 51 条长列表无崩溃无 ANR；iPad 无溢出报错，顺带发现并修复了平板卡片布局问题）
6. 合规与上架（流程周期长，尽早启动并行走）：隐私政策+用户协议页 → App 备案 → 安卓软著 → 上架华为/小米/App Store
