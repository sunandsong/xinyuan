# 人生清单

Flutter 前端 + CloudBase（腾讯云开发）TypeScript 后端的个人心愿清单 App。

## 产品原则

- **不接第三方付费 AI API（Claude/OpenAI 等）做运行时功能。** 之前评估过用 Claude API
  给自定义心愿生成里程碑拆解，用户明确表示不想为这类小功能引入按量计费的外部依赖，
  改成了纯本地免费方案（关键词规则 + 通用兜底模板，见 `frontend/lib/presets.dart` 的
  `stepTemplateFor`）。后续遇到类似"能不能让 AI 生成 XXX"的需求，默认先考虑规则/模板/
  本地算法能不能顶上去，不要默认就去接付费 API；真要接，先跟用户确认这个取舍。
