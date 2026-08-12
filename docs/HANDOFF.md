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
| C App 端配套 | 未写计划 | ⬜ **下一步从这里开始**（拉 /config、登录设备上报、埋点 track()、公告横幅、强更提示、封禁提示；做完需发版） |

### 恢复方法

计划 B 已完成，直接进入计划 C（先写计划再实现）。管理端本地开发：`cd admin && npm run dev`（走 vite 代理）；部署：`npm run deploy`。

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
- 用户手机/模拟器因 2026-08-11 JWT 密钥轮换需重新登录一次。
- 上线前待办：恢复本地缓存+增量拉取（见 CLAUDE.md 产品原则与 specs 里的记录）——「云为权威 + 缓存加速 + 失败明示」三件套。

## 专业化路线（2026-08-12 评估，按顺序执行）

1. 管理端收尾（计划 B Task 2-8 → 计划 C）
2. 崩溃监控：接腾讯 Bugly（免费，约半天）——没有它线上崩溃完全不可见
3. 本地通知做成真功能：flutter_local_notifications，场景=任务到期提醒 + 时光胶囊开启日（留存命脉，约一天）
4. 增量拉取+缓存恢复（已有待办，「云为权威+缓存加速+失败明示」三件套，约半天）
5. 一轮系统性稳定测试：弱网 / 杀进程恢复 / 低端机 / 平板
6. 合规与上架（流程周期长，尽早启动并行走）：隐私政策+用户协议页 → App 备案 → 安卓软著 → 上架华为/小米/App Store
