# 人生清单 · 后端（CloudBase 云函数 / TypeScript）

设计见 [`../docs/backend-design.md`](../docs/backend-design.md)。
底座：**CloudBase 云开发（免费额度起步）** + EdgeOne（二期做加速/分享页）。

## 目录
```
src/
  index.ts          # CloudBase 云函数入口（HTTP 访问服务）
  local-server.ts   # 本地开发服务器（MODE=mock，不打云）
  router.ts         # 路由 + 鉴权
  http.ts           # 请求/响应抽象 + 极简路由
  auth.ts           # 取当前 uid（mock / CloudBase 内置认证）
  db.ts             # 数据访问：MockDb（内存） / CloudDb（CloudBase 文档库）
  config.ts         # 运行模式、环境、集合名
  types.ts          # User / Wish / Task / Share
  handlers/         # me / sync / share
```

## 本地开发（不耗云额度）
```bash
npm install
npm run dev          # MODE=mock，http://127.0.0.1:8787
```
用 `x-mock-uid` 头模拟登录用户。示例：
```bash
# 健康检查
curl http://127.0.0.1:8787/api/health

# 拉取增量（默认 uid=u_dev）
curl 'http://127.0.0.1:8787/api/sync/pull?since=0' -H 'x-mock-uid: u_dev'

# 上传一条心愿
curl -XPOST http://127.0.0.1:8787/api/sync/push -H 'x-mock-uid: u_dev' \
  -H 'content-type: application/json' \
  -d '{"wishes":[{"_id":"w1","title":"去冰岛看极光","color":"F5D08C","done":false,"updatedAt":1730000000000}]}'
```

## API
| 方法 | 路径 | 鉴权 | 说明 |
|------|------|------|------|
| GET | `/api/health` | 否 | 健康检查 |
| GET | `/api/me` | 是 | 获取资料（无则自动建） |
| PATCH | `/api/me` | 是 | 改昵称/头像 |
| DELETE | `/api/auth/account` | 是 | 注销（软删除 + 级联） |
| GET | `/api/sync/pull?since=<ts>` | 是 | 增量拉取（含软删除） |
| POST | `/api/sync/push` | 是 | 批量上传（LWW） |
| POST | `/api/share` | 是 | 生成心愿分享短码 |
| GET | `/api/share/:code` | 否 | 公开读取分享快照 + 计数 |

> 账号的注册/登录/找回用 **CloudBase 内置邮箱认证**，不在本函数里；App 端用 CloudBase SDK 登录后带令牌调用（见设计文档 §5 方案 A）。

## 部署到 CloudBase
1. 装 CLI：`npm i -g @cloudbase/cli`，`tcb login`。
2. 控制台开环境，开启**邮箱认证**，建集合 `users/wishes/tasks/shares` 与索引（见设计文档 §3）。
3. 构建：`npm install && npm run build`（产物在 `dist/`）。
4. 部署云函数（Node.js），入口 `index.main`，开启 **HTTP 访问服务**；环境变量：
   - `MODE=cloud`
   - `CLOUDBASE_ENV_ID=<你的环境ID>`
5. 联调：把 App 的 API base 指向云函数 HTTP 地址，注册→登录→同步跑通。
6. 二期：接 EdgeOne，`/api/*` 回源到该地址，`/s/:code` 分享页用边缘函数。

## 待接入 CloudBase 时需确认的点
- `auth.ts` 里校验访问令牌取 uid 的 SDK 方法名（`getEndUserInfo` / `verifyToken`），按当前 SDK 对齐。
- `db.ts` 里 CloudBase database 查询/更新返回结构，按控制台实际微调。
