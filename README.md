# 人生清单

不留遗憾，活成自己想要的样子。

## 目录结构

```
frontend/   Flutter App（iOS / Android）
backend/    CloudBase 云函数（TypeScript）后端
docs/       设计文档
```

- **frontend/** — Flutter 客户端。见 [frontend/README.md](frontend/README.md)（Flutter 默认说明）。
  开发：`cd frontend && flutter run`。
- **backend/** — 后端 API（账号 / 云同步 / 分享）。见 [backend/README.md](backend/README.md)。
  本地开发（不耗云额度）：`cd backend && npm install && npm run dev`。
- **docs/** — [backend-design.md](docs/backend-design.md) 等设计文档。
