# 网页版注销页 — 应用商店政策对照

对照对象：本目录的 [index.html](index.html) + 后端 `POST /api/account-deletion`
（[backend/src/handlers/legal.ts](../backend/src/handlers/legal.ts) 里的 `accountDeletionSubmit`）

**流程**：网页填账号 + 密码 → 密码校验通过后登记进 `deletion_requests` →
管理端「注销申请」页人工点「执行注销」（`POST /admin/users/:uid/delete`，即 `softDeleteUser`）。
页面向用户承诺 **30 天内完成**，执行前账号仍可正常使用。
密码校验不能拆：账号没绑邮箱手机，事后没有任何办法核实申请人是不是号主。

核对日期：2026-08-17

线上地址：<https://renshengqingdan-d8feva5q55d12bab-1258070735.tcloudbaseapp.com/account-deletion/>
部署方式：`tcb hosting deploy delete account-deletion -e renshengqingdan-d8feva5q55d12bab`

**说明：下表「原文要求」一列全部是政策原文引用，未作解释或推断。「本站」一列是对照结论。**

来源：

- Apple：[App Store Review Guidelines 5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/) · [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- Google：[Play — 应用账号删除要求](https://support.google.com/googleplay/android-developer/answer/13327111)

---

## Apple

| 原文要求 | 本站 |
|---|---|
| "apps submitted to the App Store that support account creation must also let users initiate deletion of their account **within the app**" | ✓ App 内已有：我的 → 注销账号（`DELETE /api/auth/account`），本站是给已卸载 App 的人用的 |
| "Make the account deletion option easy to find in your app. Typically, it's included in the app's account settings." | ✓ 在「我的」页底部 |
| "Offer to delete the entire account record, along with associated personal data. You may include additional options, but only offering to temporarily deactivate or disable an account is insufficient." | ✓ 管理端执行 `softDeleteUser`：账号 + 心愿 + 任务 + 时光胶囊都删；保留项见下 |
| "If people need to visit a website to finish deleting their account, include a link directly to the page on your website where they can complete the process." | ✓ 不需要——App 内就能删完，本站是并行入口 |
| "Keep users informed. If the deletion request will take additional time to complete, let them know. If your app supports in-app purchases, help people understand how billing and cancellations will be handled." | ✓ 页面明确写了「最长 30 天」「执行前账号仍可正常使用」；本 App 没有内购 |
| "Apps not operating in highly regulated industries should not require people to make a phone call, send an email, or go through other support flows." | ✓ 网页填账号 + 密码即可，不需要打电话、发邮件或走客服；App 内那条路径是立即生效的 |
| "Apps that support Sign in with Apple should use the Sign in with Apple REST API to revoke user tokens." | — 未接 Sign in with Apple |

## Google Play

| 原文要求 | 本站 |
|---|---|
| "provide users with an in-app path to delete their app accounts and associated data" | ✓ App 内「我的 → 注销账号」 |
| "provide a web link resource where users can request app account deletion and associated data deletion" | ✓ 本站正是这个，填进 Play Console「数据安全」表单 |
| "When you delete an app account based on a user's request, you must also delete the user data associated with that app account." | ✓ 人工执行（Google 认可申请渠道：原文用的是 request）；**前提是申请真的被处理**，见下方风险 |
| weblink "functional (for example, loads without error)" | ✓ 已验证 200 |
| "relevant in scope (the pathway to request account deletion should be prominently featured and easily discoverable on the page)" | ✓ 首屏即表单 |
| "reference the app or developer name (that is, as it appears on your store listing in Google Play)" | ✓ 品牌名「人生清单」+ App 图标；**商店列表上的名字如果不是这四个字，要改 `applyConfig` 里的 `brandName`** |
| "The user must be able to request deletion of their account through the pathway." | ✓ |
| "your web resource should give users a way to request that their data be deleted without sending the user back to the app" | ✓ 不需要回到 App，也不需要 App 里的 token |
| "you must clearly inform users about your data retention practices, for example, within your privacy policy." | ✓ 《隐私政策》第七节「数据保留」，页脚直链 |
| "Am I required to fill out account deletion questions within the Data safety form in Play Console? Yes…" | ☐ Play Console 里的动作，还没填 |

保留数据的允许范围，原文："It is possible that your app may need to retain certain data for legitimate reasons such as security, fraud prevention or regulatory compliance."

## 唯一的真实风险：申请堆着没人处理

政策不禁止人工处理，但「受理了却不执行」直接违反上面那条 must。降低风险的措施：

- 管理端侧边栏「注销申请」带未处理数量角标（[admin/src/App.tsx](../admin/src/App.tsx) 的 `usePendingDeletions`），一进后台就能看见
- 承诺写的是 30 天，留了余量
- 没有邮件/推送提醒，**仍然依赖你自己定期看管理端**

## 实际删除范围

管理端点「执行注销」后走 `softDeleteUser`（[backend/src/db.ts](../backend/src/db.ts)），给 `users` / `wishes` / `tasks` / `letters`
打 `deleted` 标记：账号无法再登录，内容不再对任何人展示，同步也拉不到。

注销后仍保留：`logins`（设备型号 / IP / 时间）、`crashes`、`events`、`feedback`。
按上面那条原文属于「security, fraud prevention」允许的范围，并已在《隐私政策》第七节写明。

## 待办

- [ ] Play Console「数据安全」表单里填本站地址 + 回答账号删除相关问题
- [ ] 定期看管理端「注销申请」页，别让申请超过 30 天
- [ ] App Store Connect 的 Account Deletion URL 也填本站地址（选填项，填了少一个被问的理由）
- [ ] 商店列表上的应用名跟 `brandName` 核对一致
- [ ] 有对外邮箱之后填 `applyConfig` 的 `contactEmail`（现在留空，页脚不显示「联系我们」）
- [ ] `logins` / `crashes` / `events` / `feedback` 的例行清理还没有实现，隐私政策承诺了「保留一段时间后清理」
