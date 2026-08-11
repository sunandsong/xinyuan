# 管理端后端 Implementation Plan（计划 A / 共 3 份）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 CloudBase 云函数上加齐管理端所需的全部后端能力：管理鉴权、内容配置集合 CRUD、用户管理、登录/活跃/埋点采集、App 配置下发、全库导出、审计与额度查询。

**Architecture:** 全部代码进现有 `backend/src`；管理 API 统一挂 `/admin/*` 前缀走 `X-Admin-Key` 鉴权（独立于用户 JWT）；内容表用一个通用 CRUD 工厂避免为 11 张表写 11 遍；对 App 的公开配置走无鉴权只读的 `GET /config`。所有管理写操作落 `admin_audit`。

**Tech Stack:** TypeScript + @cloudbase/node-sdk（现有）；额度查询走腾讯云 API（`DescribeEnvResourceUsage`，签名用 Node 内置 crypto，不新增依赖）。

## Global Constraints

- 不新增 npm 运行时依赖（腾讯云 API 签名手写 TC3-HMAC-SHA256）。
- `ADMIN_KEY` 未配置时所有 `/admin/*` 返回 403（`admin_disabled`）。
- users 表任何对外输出必须剥 `passwordHash`（沿用 `sanitizeUser` 模式）。
- 同步集合（wishes/tasks/letters）管理端删除一律软删并刷新 `updatedAt=Date.now()`。
- 内容集合命名（与设计稿一致）：`preset_wishes` `preset_steps` `poster_task` `poster_wish` `poster_done` `hero_images` `achv_defs` `spots` `blockwords` `announcements`；日志集合：`logins` `events` `admin_audit`。
- 管理 API 响应沿用现有 `ok()/bad()` 格式；CORS 允许任意来源（管理端静态托管域名部署后可收紧）。
- 每个任务结束跑 `cd backend && npx tsc --noEmit` 必须零错误。

---

### Task 1: 管理鉴权中间件 + CORS + 路由骨架

**Files:**
- Create: `backend/src/handlers/admin/auth.ts`
- Modify: `backend/src/config.ts`（加 `ADMIN_KEY`、`TC_SECRET_ID`、`TC_SECRET_KEY` 导出，均 `process.env.X || ''`）
- Modify: `backend/src/router.ts`（挂 `/admin/*` 分发 + OPTIONS 预检 + 响应加 CORS 头）
- Modify: `backend/src/http.ts`（`Res` 输出统一带 `Access-Control-Allow-Origin: *`、`Access-Control-Allow-Headers: content-type,x-admin-key,authorization`）

**Interfaces:**
- Produces: `requireAdmin(req: Req): Res | null` —— 校验通过返回 null，否则返回 403/401 Res。后续所有 admin handler 第一行调用。
- Produces: router 内 `adminRoutes: Route[]` 数组，后续任务往里加 `route('GET', '/admin/xxx', ...)`。

- [ ] **Step 1:** 写 `auth.ts`：
```ts
import { ADMIN_KEY } from '../config';
import { forbidden, Req, Res, unauthorized } from '../http';

/** 管理鉴权：没配 ADMIN_KEY 宁可整体不可用也不能裸奔 */
export function requireAdmin(req: Req): Res | null {
  if (!ADMIN_KEY) return forbidden('admin_disabled');
  const key = String(req.headers?.['x-admin-key'] ?? '');
  if (key !== ADMIN_KEY) return unauthorized();
  return null;
}
```
（`http.ts` 若无 `forbidden` 则补：`export const forbidden = (err: string): Res => ({ status: 403, body: { error: err } })`，对齐现有 `unauthorized` 写法。）
- [ ] **Step 2:** router：在 `handle()` 里 path 以 `/admin` 开头时先 `requireAdmin`，通过后走 `adminRoutes` 分发；OPTIONS 请求直接 204 + CORS 头。加一条冒烟路由 `route('GET', '/admin/ping', async () => ok({ pong: true }))`。
- [ ] **Step 3:** `npx tsc --noEmit` 零错误。
- [ ] **Step 4:** 本地验证逻辑（无需部署）：`node -e` 直接调 handle 模拟三种情况——无 key→401、错 key→401、对 key→200、未配 ADMIN_KEY→403。四个断言都过。
- [ ] **Step 5:** Commit：`git commit -m "feat(admin): 管理鉴权中间件 + CORS + /admin 路由骨架"`

### Task 2: 通用内容表 CRUD 工厂（11 张表一次搞定）

**Files:**
- Create: `backend/src/handlers/admin/content.ts`
- Modify: `backend/src/db.ts`（加通用方法）
- Modify: `backend/src/router.ts`

**Interfaces:**
- Consumes: `requireAdmin`（已由路由层统一调用，handler 内不再重复）。
- Produces（db.ts）:
  - `listDocs(col: string, opts: { skip?: number; limit?: number; where?: Record<string, unknown> }): Promise<{ items: any[]; total: number }>`
  - `upsertDoc(col: string, id: string | undefined, patch: Record<string, unknown>): Promise<string>`（无 id 则新建返回新 id；有 id 则 update）
  - `deleteDoc(col: string, id: string): Promise<void>`（物理删，仅内容表用）
- Produces（HTTP）: `GET/POST /admin/content/:col`、`POST /admin/content/:col/delete`，`:col` 白名单 = Global Constraints 的 10 个内容集合（不含日志表）。

- [ ] **Step 1:** db.ts 实现三个通用方法（照 `upsertBatch` 现有风格；listDocs 用 `.where(where).skip(skip).limit(limit).get()` + `.count()`）。
- [ ] **Step 2:** content.ts：白名单常量 `CONTENT_COLS`；GET 列表（query: skip/limit/字段过滤如 `enabled`）；POST upsert（body: `{id?, doc}`，写前自动补 `updatedAt: Date.now()`）；POST delete（body: `{id}`）。`:col` 不在白名单 → `bad('unknown_collection')`。每次写操作调 Task 8 的 `audit()`（先留 TODO 注释位，Task 8 接线——本计划内完成）。
- [ ] **Step 3:** router 注册三条路由。`npx tsc --noEmit`。
- [ ] **Step 4:** Commit。

### Task 3: 打点采集——登录日志、活跃心跳、行为埋点

**Files:**
- Modify: `backend/src/handlers/auth.ts`（login 成功后写 `logins` + 盖 `lastLoginAt`）
- Modify: `backend/src/handlers/sync.ts`（pull 时节流盖 `lastActiveAt`）
- Create: `backend/src/handlers/events.ts`（`POST /events` 用户鉴权、批量）
- Modify: `backend/src/db.ts`、`backend/src/router.ts`、`backend/src/types.ts`

**Interfaces:**
- Produces（HTTP，用户鉴权）: `POST /events` body `{ events: [{ event: string, props?: object, at: number }] }`，上限一次 50 条，超出截断；写入 `events` 集合附 `uid`。
- Produces（login 请求体新增可选字段）: `device?: string, os?: string, appVersion?: string`——写入 logins 文档 `{uid, at, device, os, appVersion, ip}`；`ip` 取 `req.headers['x-forwarded-for']` 首段。
- Produces（db）: `touchUserField(uid, field, ms)`；`lastActiveAt` 节流：仅当 `now - (user.lastActiveAt ?? 0) > 3600_000` 才写。

- [ ] **Step 1:** types.ts 给 UserProfile 加 `lastLoginAt?/lastActiveAt?/banned?/isDemo?`（后两个 Task 5/6 用，一次加齐）。
- [ ] **Step 2:** 实现三处采集 + 路由注册。login 写日志失败要 catch 吞掉——打点绝不能挡登录。
- [ ] **Step 3:** `npx tsc --noEmit`。
- [ ] **Step 4:** Commit。

### Task 4: 管理查询 API——stats / 用户列表详情 / 反馈 / 登录日志 / 事件

**Files:**
- Create: `backend/src/handlers/admin/queries.ts`
- Modify: `backend/src/db.ts`、`backend/src/router.ts`

**Interfaces（全部 GET，/admin 前缀，X-Admin-Key）:**
- `/admin/stats` → `{ totals: {users,todayActive,wishes,doneWishes,tasks,letters,feedbackOpen}, series: {signups:[[day,n]], dau:[[day,n]], logins:[[day,n]]}, retention: {d1,d7,d30}, topEvents:[[event,n]], topWishes, topPlaces, activeBuckets:{today,week,month,sleep} }`——近 30 天；全部排除 `isDemo`；topWishes/topPlaces 复用现有 `topWishTitles/topPlaces` 并过滤 `blockwords`。
- `/admin/users?q=&sort=&skip=` → 列表（剥 passwordHash）+ 每人心愿 done/total（按 uid 批量聚合 wishes，一次查询内存汇总）。
- `/admin/users/:uid` → 详情 + 该用户 wishes/tasks/letters 计数 + 最近 10 条登录。
- `/admin/feedback?skip=`、`/admin/logins?uid=&days=&skip=`、`/admin/events?event=&uid=&days=&skip=`。

- [ ] **Step 1:** db.ts 加需要的聚合查询（沿用 QUERY_LIMIT 分页扫描模式；stats 的按天序列在内存 reduce）。
- [ ] **Step 2:** queries.ts 实现五个 handler + 路由注册。
- [ ] **Step 3:** `npx tsc --noEmit`；Commit。

### Task 5: 用户管理写操作——重置密码 / 封禁 / 删号 / 补发 / 重置昵称头像 / 反馈处理

**Files:**
- Create: `backend/src/handlers/admin/users.ts`
- Modify: `backend/src/handlers/auth.ts`（login 校验 `banned` → `bad('banned')`）、`backend/src/auth.ts` 或 getUid 中间件（banned 用户所有请求 401）
- Modify: `backend/src/router.ts`

**Interfaces（POST，/admin 前缀）:**
- `/admin/users/:uid/reset-password` → 生成 8 位随机密码（`crypto.randomBytes` 映射到无歧义字符集，去掉 0O1lI），`hashPassword` 写库，返回 `{password}` 明文（仅此一次）。
- `/admin/users/:uid/ban` body `{banned: boolean}`；`/admin/users/:uid/delete`（复用现有软删逻辑）。
- `/admin/users/:uid/grant` body `{achievements?: {slug:ms}, checkins?: {place:ms}}` → 并集合入（不覆盖不删除）。
- `/admin/users/:uid/reset-profile` body `{nickname?: true, avatar?: true}` → 昵称重置为 `用户+uid后4位`、avatarUrl 置 null。
- `/admin/feedback/:id` body `{handled?: boolean, note?: string}`；`/admin/feedback/:id/delete`。

- [ ] **Step 1:** 实现全部 handler + banned 拦截（getUid 处查 user.banned 成本高——改为在 sync/pull 与 login 两个入口校验即可，拦住数据面）。
- [ ] **Step 2:** `npx tsc --noEmit`；Commit。

### Task 6: 演示用户接口

**Files:**
- Create: `backend/src/handlers/admin/demo.ts`
- Modify: `backend/src/router.ts`

**Interfaces:**
- `GET /admin/demo-users` → users where `isDemo=true`（不剥计数字段）。
- `POST /admin/demo-users` body `{id?, nickname, gender?, avatarUrl?, taskCount, achievements: string[], doneWishTitles: string[], checkins: string[]}`：
  写 user 文档（`isDemo:true`，无 account/passwordHash，登录不了）；计数自动推导
  `doneCount=doneWishTitles.length, achvCount=achievements.length, placeCount=checkins.length`；
  achievements/checkins 映射为 `{key: Date.now()}`；**diff 同步心愿文档**：为新增标题在 wishes 建
  `{_id:'demo_'+uid+'_'+n, uid, title, done:true, doneAt:Date.now(), updatedAt:Date.now()}`，为移除的标题打软删。
- `POST /admin/demo-users/:uid/delete` → 硬删 user + 其全部 wishes（demo 数据不留尸体）。
- 迁移端点 `POST /admin/demo-users/mark` body `{uids: string[]}` → 给现存假账号补 `isDemo:true`（一次性用）。

- [ ] **Step 1:** 实现 + 路由。`npx tsc --noEmit`；Commit。

### Task 7: App 配置下发 GET /config + 屏蔽词生效

**Files:**
- Create: `backend/src/handlers/config.ts`（**用户鉴权即可访问**，不走 admin）
- Modify: `backend/src/handlers/insights.ts` + `leaderboard.ts`（榜单输出过滤：标题命中 blockwords 的不返回；昵称命中的替换为 `用户${uid.slice(-4)}`）
- Modify: `backend/src/router.ts`

**Interfaces:**
- `GET /config` → `{ presetWishes: string[], presetSteps: {title, steps[]}[], posters: {task:[], wish:[], done:[]}（每项 {url, slogan}）, heroImages: string[], achvDefs: {slug,name,desc,icon}[], spots: {name,lat,lng}[], announcements: {title,body}[]（仅生效中）, minVersion: string }`——全部只取 `enabled != false` 按 `sort` 排序；结果整包无分页（App 一次拉走）。minVersion 存 `announcements` 集合特殊文档 `_id='sys_min_version'`。
- 屏蔽词匹配：包含式（`title.includes(word)`）。

- [ ] **Step 1:** 实现 config.ts + 榜单过滤 + 路由。`npx tsc --noEmit`；Commit。

### Task 8: 审计日志 + 全库导出 + 额度查询

**Files:**
- Create: `backend/src/handlers/admin/audit.ts`、`backend/src/handlers/admin/quota.ts`、`backend/src/handlers/admin/export.ts`
- Modify: Task 2/5/6 的写 handler 统一接 `audit(action, target, detail)`（写 `admin_audit`，失败吞掉）

**Interfaces:**
- `GET /admin/audit?skip=` → 审计列表。
- `GET /admin/export` → 全集合 JSON（users 剥 passwordHash；单集合按 QUERY_LIMIT 翻页拉全）。
- `GET /admin/quota` → 调腾讯云 `tcb.DescribeEnvResourceUsage`（TC3-HMAC-SHA256 签名，region ap-shanghai）返回本月读/写/函数调用/存储用量；密钥未配或调用失败 → `{available:false}`（前端显示"未配置密钥"，不报错）。
- 签名实现放 `quota.ts` 内部（≈40 行，crypto.createHmac），**不引 SDK**。

- [ ] **Step 1:** 实现三个模块 + 把 audit 接进所有写操作 + 路由。`npx tsc --noEmit`；Commit。

### Task 9: 数据初始化脚本 + 部署 + 全量冒烟

**Files:**
- Create: `backend/scripts/seed-content.ts`（一次性：把 App 内置的 50 默认心愿、里程碑模板、荣誉文案、景点库、海报文案灌入对应集合；图片 URL 先留空由管理端上传后补）
- Modify: `backend/cloudbaserc.json`（加 ADMIN_KEY、TC_SECRET_ID/KEY 环境变量——**提醒用户自己生成填入**）

**Interfaces:** 无（收尾任务）。

- [ ] **Step 1:** 写 seed 脚本（数据源直接从 `frontend/lib/presets.dart`、`spot_geo.dart` 提取转 JSON 常量；跑法 `ts-node scripts/seed-content.ts`，幂等：已存在同名文档跳过）。
- [ ] **Step 2:** 用户确认 ADMIN_KEY 已配置后 `npm run deploy`。
- [ ] **Step 3:** curl 冒烟清单（每条都要跑）：`/admin/ping` 无 key 401/带 key 200；`/admin/stats` 200 且字段齐；`/admin/content/preset_wishes` 返回 50 条；`/config` 用户 token 200 且各字段非空；`POST /events` 批量 3 条 200；登录一次后 `/admin/logins` 能看到记录；`/admin/export` 200 且包含全部集合键；`/admin/quota` 返回用量或 `{available:false}`。
- [ ] **Step 4:** Commit + push。

---

**Self-review 记录：** 设计稿逐节核对——鉴权✓(T1) 内容表 CRUD✓(T2) 打点三件✓(T3) 查询统计✓(T4) 用户写操作✓(T5) 演示用户✓(T6) config+屏蔽✓(T7) 审计/导出/额度✓(T8) 灌数据+部署✓(T9)。软删语义在 T2（同步集合不在内容白名单，管理端对 wishes/tasks/letters 的编辑走既有 upsert 语义，恢复=把 deleted 改 false 也经 upsert——由 T2 的通用 upsert 对这三个集合放行但强制刷 updatedAt，白名单额外含三个同步集合，删除动作对它们改为软删）。类型/命名一致性✓。
