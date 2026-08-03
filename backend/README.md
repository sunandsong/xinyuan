# 人生清单 · 后端（CloudBase 云函数 / TypeScript）

设计见 [`../docs/backend-design.md`](../docs/backend-design.md)。
底座：**CloudBase 云开发**。**没有 mock 模式**，数据只有一个去处：云端文档库。

## 目录
```
src/
  index.ts          # CloudBase 云函数入口（HTTP 访问服务）
  local-server.ts   # 本地开发服务器：把 handler 挂到本机端口，数据照样读写云端
  router.ts         # 路由 + 鉴权
  http.ts           # 请求/响应抽象 + 极简路由
  auth.ts           # 从 JWT 取当前 uid
  db.ts             # 数据访问：CloudDb（CloudBase 文档库）
  config.ts         # 环境 ID、JWT 密钥、集合名
  password.ts       # scrypt 密码哈希
  jwt.ts            # HS256 签发/校验
  types.ts          # UserProfile / Wish / Task / Letter / Share
  handlers/         # auth / me / sync / share / upload
```

## 本地开发
```bash
npm install
tcb login                                    # 拿云端凭证
CLOUDBASE_ENV_ID=<你的环境ID> npm run dev      # http://127.0.0.1:8787
```
注意：**本地服务也是真读写云端**，改的是线上数据。

## 测试
```bash
sh test-api.sh                               # 默认直接打线上
API_BASE=http://127.0.0.1:8787 sh test-api.sh # 打本地服务（数据同样落云）
```
账号名带时间戳自动生成，跑完会注销掉，不会污染。

## API
| 方法 | 路径 | 鉴权 | 说明 |
|------|------|------|------|
| GET | `/api/health` | 否 | 健康检查 |
| POST | `/api/auth/register` | 否 | 账号密码注册（账号 3-20 位字母/数字/下划线）+ 签发 JWT |
| POST | `/api/auth/login` | 否 | 账号密码登录，签发 JWT |
| DELETE | `/api/auth/account` | 是 | 注销（软删除 + 级联），账号名随即释放 |
| GET | `/api/me` | 是 | 获取资料（无则自动建） |
| PATCH | `/api/me` | 是 | 改昵称/头像/成就 |
| GET | `/api/sync/pull?since=<ts>` | 是 | 增量拉取（含软删除标记） |
| POST | `/api/sync/push` | 是 | 批量上传（LWW，客户端按 80KB 分块） |
| POST | `/api/share` | 是 | 生成心愿分享短码 |
| GET | `/api/share/:code` | 否 | 公开读取分享快照 + 计数 |
| POST | `/api/upload` | 是 | 换云存储一次性直传凭证（图片本体不过云函数） |
| POST | `/api/photo-urls` | 是 | 用稳定链接换新鲜的带签名临时链接 |

> 账号体系自管：账号名 + scrypt 密码哈希 + JWT（HS256），不依赖 CloudBase 内置认证，
> 也不发邮件、不接短信。`getUserByAccount` 会排除已注销的记录，注销后同名可重新注册。

## 部署
```bash
tcb login
npm run deploy       # = 编译 + 拷到 cloudfunctions/api + tcb fn deploy api --force
```
云函数环境变量（在 `cloudbaserc.json` 里）：
- `MODE=cloud`（历史字段，代码已不读它）
- `CLOUDBASE_ENV_ID=<你的环境ID>`
- `JWT_SECRET=<openssl rand -hex 32>`

集合：`users` / `wishes` / `tasks` / `letters` / `shares`。
索引建议：`users.account` 唯一（小写）、`wishes {uid, updatedAt}`、`tasks {uid, day}`、`shares.code` 唯一。
