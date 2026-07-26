# 人生清单 · 后端设计文档（v0.1）

> 目标：给「人生清单」App 加后端，支持账号、心愿/任务云同步、心愿分享；部署到腾讯云 EdgeOne。
> 原则：**先做日活、少踩坑、能快速迭代**。先把「账号 + 云同步」跑通，分享页随后。

---

## 1. 需求范围

| 模块 | 说明 | 优先级 |
|------|------|--------|
| 账号 | 注册 / 登录 / 退出 / 注销；JWT 鉴权 | P0 |
| 云同步 | 心愿、任务、用户资料（昵称/头像）多端同步；增量拉取/上传 | P0 |
| 分享 | 心愿生成公开只读分享页 + 短链（重点，但可稍后） | P1 |
| 年度回顾 | 已完成心愿聚合统计（后期可 AI 分类统计） | P2 |

当前 App 数据结构（来自 `lib/data.dart`）：`Wish`（title/color/desc/done/doneAt/quote/location/hero…）、`Task`（title/day/done/time/wishId…）、用户资料（nickname/avatarEmoji）。后端数据模型据此设计。

---

## 2. 技术选型与架构

### 2.1 关键约束：EdgeOne 边缘函数 ≠ 应用服务器
EdgeOne 更接近腾讯版 Cloudflare：
- **Pages**：托管静态站点（放分享页、落地页），全国/全球边缘加速。
- **边缘函数（Edge Functions / Pages Functions，JS/TS）**：`functions/` 目录映射路由，适合**轻量**逻辑（跳转、缓存、鉴权校验、限流）。
- **KV 存储**：边缘键值库，读快，适合短链、验证码、计数、热点缓存。
- ⚠️ **不擅长直连传统数据库**：边缘运行时拿不住 MySQL/Mongo 的长连接（和 Cloudflare Workers 同样的限制）。把主数据库放边缘函数直连 = 踩坑。

### 2.2 推荐架构（CloudBase 免费额度起步）

早期用 **腾讯云 CloudBase（云开发）免费额度** 起步：文档数据库 + 云函数 + 身份认证 + 静态托管一站式，**在国内、零成本、免运维**。EdgeOne 放在前面做加速与分享页。

```
                       ┌─────────────────────────────┐
   Flutter App ──────► │        腾讯云 EdgeOne         │  （加速层，可后置）
                       │  Pages 静态（分享页/落地页）    │
                       │  边缘函数（短链跳转/缓存/限流） │
                       │  KV（短链映射/计数）           │
                       └──────────────┬──────────────┘
                                      │  /api/* 加速 · /s/:code 分享页
                                      ▼
                       ┌─────────────────────────────┐
                       │     腾讯云 CloudBase（云开发）  │
                       │  ┌───────────────────────┐  │
                       │  │ 身份认证（内置邮箱登录） │  │  注册/登录/找回
                       │  ├───────────────────────┤  │
                       │  │ 云函数 Node.js（业务 API）│ │  同步/分享/资料
                       │  ├───────────────────────┤  │
                       │  │ 文档数据库（类 Mongo）    │ │  users/wishes/tasks/shares
                       │  ├───────────────────────┤  │
                       │  │ 云存储（头像等，可选）    │  │
                       │  └───────────────────────┘  │
                       └─────────────────────────────┘
```

**分工：**
- **CloudBase**：承载账号、业务 API（云函数）、主数据（文档库）。免费额度够验证；日活起来要扩容再平滑迁腾讯云 MongoDB。
- **EdgeOne**：加速 + 分享页静态托管 + 短链/缓存/限流边缘函数。**可以第二阶段再接**——第一阶段 App 直连 CloudBase 也能先跑通。
- App 访问方式：CloudBase 云函数开 **HTTP 访问服务**，App 以普通 REST 调用（或经 EdgeOne 加速转发）。

### 2.3 数据库为什么用文档型（CloudBase 文档库 / 后期 Mongo）
- 心愿/任务是**天然嵌套**的数据，一个用户一批文档，结构直观、读写一次搞定。
- **改结构灵活**：迭代期字段常变（加分类、分享次数…），文档型不用改表结构、不用迁移，符合「快速迭代」。
- 同步只需按 `updatedAt` 拉增量，文档型查询足够。
- CloudBase 文档库与 MongoDB 模型基本一致，**后期要扩容可平滑迁移**，架构不用重写。

> 备选与迁移路径：
> - **EdgeOne KV 单干**：最省，但查询弱（列某用户所有心愿要手动维护索引键）→ 只做短链/缓存，不做主库。
> - **腾讯云 PostgreSQL/MySQL**：关系清晰，但无服务器连库要连接池代理，且改字段成本高。
> - **腾讯云 MongoDB（正式）**：几百元/月起，等有日活、要正式上线再从 CloudBase 平滑迁过去。

---

## 3. 数据模型（MongoDB 集合）

### `users`
```jsonc
{
  "_id": "uid_xxx",              // 用户 ID
  "email": "user@example.com",   // 登录标识（唯一索引，小写存储）
  "emailVerified": false,        // 邮箱是否验证（二期做验证邮件）
  "passwordHash": "...",         // bcrypt/argon2；第三方登录则空
  "nickname": "松",
  "avatarEmoji": "🌟",           // null = 用昵称首字
  "createdAt": 1730000000000,
  "updatedAt": 1730000000000
}
```

### `wishes`
```jsonc
{
  "_id": "w_xxx",
  "uid": "uid_xxx",              // 归属用户（索引：{uid, updatedAt}）
  "title": "去冰岛看极光",
  "color": "F5D08C",             // 十六进制
  "desc": null,
  "done": false,
  "doneAt": null,
  "quote": null,                 // 完成寄语
  "location": null,
  "heroIndex": null,             // 完成时的凭证图
  "createdAt": 1730000000000,
  "updatedAt": 1730000000000,
  "deleted": false               // 软删除，便于多端同步
}
```

### `tasks`
```jsonc
{
  "_id": "t_xxx",
  "uid": "uid_xxx",              // 索引：{uid, day}
  "title": "给妈打个电话",
  "day": "2026-07-27",           // yyyy-MM-dd
  "time": null,
  "done": false,
  "wishId": "w_xxx",             // 关联心愿，可空
  "color": "F09A9A",
  "createdAt": 1730000000000,
  "updatedAt": 1730000000000,
  "deleted": false
}
```

### `shares`（分享，P1）
```jsonc
{
  "_id": "s_xxx",
  "code": "aB3xK9",              // 短链码（唯一索引，也存 EdgeOne KV）
  "uid": "uid_xxx",
  "wishId": "w_xxx",
  "snapshot": { "title": "...", "quote": "...", "color": "..." }, // 只读快照，防源数据改动
  "views": 0,
  "createdAt": 1730000000000,
  "expireAt": null               // 可选过期
}
```

**索引建议**：`users.email` 唯一（小写）；`wishes {uid:1, updatedAt:1}`；`tasks {uid:1, day:1}`；`shares.code` 唯一。

---

## 4. API 设计

统一前缀 `/api`，JSON，鉴权走 `Authorization: Bearer <JWT>`。

### 4.1 账号
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/auth/register` | 邮箱/密码注册，返回 token |
| POST | `/api/auth/login` | 邮箱/密码登录，返回 token + 用户资料 |
| POST | `/api/auth/logout` | 退出（前端清 token；如做黑名单则记 KV） |
| DELETE | `/api/auth/account` | 注销：软删除用户 + 级联标记数据 deleted |
| GET | `/api/me` | 获取当前用户资料 |
| PATCH | `/api/me` | 改昵称/头像 |

### 4.2 同步（增量）
用「按 `updatedAt` 拉取 + 批量 upsert」的简单增量同步：

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/sync/pull?since=<ts>` | 拉取该用户 `updatedAt > since` 的心愿+任务+资料（含已删除） |
| POST | `/api/sync/push` | 批量上传本地新增/修改（body: `{wishes:[], tasks:[]}`） |

**冲突策略（先简单）**：`updatedAt` 大者胜（Last-Write-Wins）。每条数据带客户端 `updatedAt`，服务端比对；相等则以服务端为准。软删除用 `deleted:true` 传播，避免「一端删了另一端又同步回来」。

> 进阶（后期）：加 `rev` 版本号或字段级合并；现在 LWW 足够。

### 4.3 分享（P1）
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/share` | 为某心愿生成分享：写 `shares` + 写 EdgeOne KV(code→shareId)，返回短链 |
| GET | `/s/:code` | （EdgeOne 边缘函数）读 KV 命中则渲染/回源分享页，`views++` |

分享页本身是 EdgeOne Pages 上的静态模板 + 边缘函数注入快照数据，**只读、免登录、可被微信抓取**（配 OG 头，微信里有卡片预览）。

---

## 5. 鉴权方案

两种做法，二选一（推荐 A，省事）：

**A. 用 CloudBase 内置邮箱认证（推荐）**
- CloudBase 身份认证自带**邮箱密码登录 + 找回密码**，不用自己存密码哈希、发验证邮件。
- App 走 CloudBase 登录流程拿到 CloudBase 的登录态（access token），云函数里能直接拿到调用者身份（`uid`），天然防越权。
- 省掉：密码哈希、JWT 签发、找回密码逻辑。
- `users` 集合只存业务资料（nickname/avatarEmoji…），账号密码由 CloudBase 认证托管。

**B. 自管 JWT（更可移植，后期脱离 CloudBase 更容易）**
- 注册/登录成功 → 云函数签发 **JWT**（`{uid, exp}`，HS256，密钥存环境变量），密码 bcrypt/argon2 存 `users.passwordHash`。
- App 本地安全存储 token（`flutter_secure_storage`），每次请求带 `Authorization`。
- 有效期 30 天；找回密码要自己配邮件服务。

> **实际采用 B**：CloudBase 官方 Flutter 客户端 SDK 支持不稳，改用后端自管邮箱+密码+JWT，App 直接调 `/api/auth/register|login`，无需 CloudBase 客户端 SDK，完全可控、可移植。密码用 Node scrypt 哈希、JWT 用 HS256（`backend/src/{password,jwt,auth}.ts`）。
> 注销账号：业务数据级联 `deleted=true`（`DELETE /api/auth/account`）。

---

## 6. 部署落地清单

**第一阶段：CloudBase（先跑通账号 + 同步，先不接 EdgeOne）**
1. 开通 **CloudBase 云开发**，新建环境（选按量/免费额度），记下 `envId`。
2. **身份认证**：开启邮箱登录（方案 A）。
3. **文档数据库**：建集合 `users / wishes / tasks / shares`，建索引（见 §3）。
4. **云函数**：Node.js 函数，开启 **HTTP 访问服务**，暴露 `/api/*` 路由；环境变量存必要密钥。
5. **App 接入**：把本地 mock 换成 API 调用（先 auth + sync），加 loading / 失败重试 / **离线兜底**（本地先写、联网再同步）。
6. **联调**：注册→登录→本地改心愿→push→换设备 pull 验证一致。

**第二阶段：接入 EdgeOne（加速 + 分享）**
7. EdgeOne 接入域名、开启加速；`/api/*` 回源到 CloudBase 云函数 HTTP 地址。
8. **Pages** 上传分享页静态模板；**边缘函数** `/s/:code` 短链跳转 + 注入分享快照；给 `/api/*` 加限流/防刷。
9. **KV** 存短链映射、计数。分享页配 OG 头，微信里出卡片预览。

---

## 7. 分阶段落地

- **第一阶段（P0，先跑通）**：CloudBase（认证 + 云函数 + 文档库）的 `auth` + `sync`，App 接账号与云同步。EdgeOne 可暂不接。
- **第二阶段（P1）**：分享页 + 短链（EdgeOne Pages + 边缘函数 + KV）。这是「做日活/传播」的关键，重点打磨分享的高级感。
- **第三阶段（P2）**：年度回顾聚合、AI 分类统计、他人评价（暂缓项按需）。

---

## 8. 安全与成本注意
- 密码用 bcrypt/argon2，**绝不明文**；`JWT_SECRET` 只在服务端环境变量。
- 所有写接口校验 `uid` 归属，防越权改他人数据。
- 注册/登录/分享接口加 EdgeOne 边缘限流，防刷。
- 分享页只暴露 `snapshot` 快照，不泄露用户其他数据。
- 成本：SCF 按调用计费、MongoDB 按最小规格起步、EdgeOne 加速按流量——先做日活阶段量小，成本可控；先别上大规格。

---

## 9. 已定 / 下一步
- [x] 登录标识：**邮箱**（起步不接短信；微信登录后期再说）。
- [x] 后端底座：**CloudBase 云开发（免费额度）** 起步；日活起来再迁腾讯云 MongoDB。
- [x] 鉴权：优先 **CloudBase 内置邮箱认证（方案 A）**。
- [x] 云函数语言：**TypeScript**。
- [x] 开发不浪费额度：脚手架内置 **mock / cloud 双模式**，平时走本地 mock + 云函数本地运行，仅联调时打云端。
- [ ] 搭 `backend/` 脚手架（进行中）：CloudBase 云函数路由 + 数据访问 + 同步逻辑 + 分享页模板。
