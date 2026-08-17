# 账号注销页 — 应用商店政策对照

对照对象:本目录的 [index.html](index.html) + [server.py](server.py)
核对日期:2026-08-17

**说明:下表"原文要求"一列全部是政策原文引用,未作解释或推断。"本站"一列是对照结论。**

来源:

- Apple:[App Store Review Guidelines 5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/) · [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- Google:[Play — 应用账号删除要求](https://support.google.com/googleplay/android-developer/answer/13327111)

---

## Apple

| 原文要求 | 本站 |
|---|---|
| "apps submitted to the App Store that support account creation must also let users initiate deletion of their account **within the app**" | ✗ 网站替代不了,app 内必须有发起入口 |
| "Make the account deletion option easy to find in your app. Typically, it's included in the app's account settings." | — app 内的事,与本站无关 |
| "Offer to delete the entire account record, along with associated personal data. You may include additional options, but only offering to temporarily deactivate or disable an account is insufficient." | 文案 ✓(声明永久删除全部);实际 ✗ 后端确认后不执行删除 |
| "If people need to visit a website to finish deleting their account, include a link directly to the page on your website where they can complete the process." | ✓ 本站可充当该页面,app 内需直链到它 |
| "Keep users informed. If the deletion request will take additional time to complete, let them know. If your app supports in-app purchases, **help people understand how billing and cancellations will be handled**." | 部分 ✓ 写了 60 天、余额作废;✗ 没写内购/订阅的计费与取消如何处理 |
| "Apps not operating in highly regulated industries should not require people to make a phone call, send an email, or go through other support flows." | ✓ 没要求打电话或发邮件给客服 |
| "Apps that support Sign in with Apple should use the Sign in with Apple REST API to revoke user tokens." | ✗ 未实现(仅当接了 Sign in with Apple) |

受强监管行业的例外见 5.1.1(ix) 原文:"Apps that provide services in highly regulated fields (such as banking and financial services, healthcare, gambling, legal cannabis use, air travel and crypto exchanges)…"

## Google Play

| 原文要求 | 本站 |
|---|---|
| "provide users with an in-app path to delete their app accounts and associated data" | ✗ 本站不是 app 内路径 |
| "provide a web link resource where users can request app account deletion and associated data deletion" | ✓ 本站正是这个 |
| "When you delete an app account based on a user's request, you must also delete the user data associated with that app account." | ✗ 后端未执行删除 |
| weblink "functional (for example, loads without error)" | ✓ 已验证 |
| "relevant in scope (the pathway to request account deletion should be prominently featured and easily discoverable on the page)" | ✓ 首屏即表单 |
| "reference the app or developer name (that is, **as it appears on your store listing in Google Play**)" | ✗ 现在是 `示例应用`,必须改成 Play 商店列表上的名称 |
| "The user must be able to request deletion of their account through the pathway." | ✓ |
| "your web resource should give users a way to request that their data be deleted without sending the user back to the app" | ✓ 无需回到 app |
| "you must clearly inform users about your data retention practices, for example, within your privacy policy." | ✗ 隐私政策链接现在是 `#` |
| "Am I required to fill out account deletion questions within the Data safety form in Play Console? Yes, all developers will be prompted and required to answer a new set of questions." | — Play Console 里的动作,不是页面的事 |

保留数据的允许范围,原文:"It is possible that your app may need to retain certain data for legitimate reasons such as security, fraud prevention or regulatory compliance."

---

## 与政策无关的代码事实

来自读代码,不引政策:

1. 页面写"链接 24 小时后失效",但 [server.py](server.py) 的 `confirm()` 只校验 token 是否存在,未校验 `created_at`。
2. `status` 置为 `confirmed` 之后没有任何删除动作(Apple 和 Google 各有一条要求卡在这里)。
3. 申请记录含账号 ID、邮箱、IP,明文存 sqlite 且无清理机制。

## 待办

按上表 ✗ 项:

- [ ] app 内加注销发起入口(Apple/Google 都是硬要求,可复用 `POST /api/account/cancel`)
- [ ] `applyConfig` 里 `brandName` 改成 Play 商店列表上的应用名或开发者名,`logo` 一并设置
- [ ] `privacyUrl` / `termsUrl` / `contactEmail` 换成真实值,隐私政策中写明数据保留做法
- [ ] `confirmed` 之后真正删除账号及关联用户数据
- [ ] `confirm()` 加 24 小时过期校验(或改页面文案)
- [ ] 页面补内购/订阅的计费与取消说明
- [ ] 接了 Sign in with Apple 的话,删除时调 REST API 撤销 token
- [ ] 申请记录本身的保留期与清理
