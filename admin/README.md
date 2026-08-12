# 人生清单 · 管理端

React 18 + TypeScript + Vite + antd 5 + ECharts。对接后端 `/admin/*` 管理 API（`X-Admin-Key` 鉴权）。

## 线上地址

https://renshengqingdan-d8feva5q55d12bab-1258070735.tcloudbaseapp.com

打开后输入管理密钥（`backend/cloudbaserc.json` 里的 `ADMIN_KEY`）进入。密钥存 localStorage，401 自动回门禁页。

## 开发

```bash
npm install
npm run dev        # 本地开发（直连线上 API）
npx tsc --noEmit   # 类型检查
npm run build      # 产物在 dist/
```

## 部署

```bash
npm run deploy     # build + tcb hosting deploy（需先 tcb login）
```

CDN 有几分钟缓存，部署后页面没变化用无痕窗口或 `curl -H "Cache-Control: no-cache"` 验证。

注意：后端 CORS 白名单只放行上面的静态托管域名（`backend/src/http.ts` 的 `ALLOWED_ORIGINS`）。
换托管域名要同步改后端并重新部署云函数。
