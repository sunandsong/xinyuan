import { json, Res } from '../http';

/** 数据面统一的账号状态闸门。返回 null 表示放行。
 *
 * 为什么注销也要拦：注销是软删——用户文档打 deleted 标记、心愿/任务/信件全部标删，
 * 但**已经签发出去的 token 不会失效**。登录接口挡住了已注销账号，可另一台还登着的
 * 设备照样能 pull/push。2026-08-18 在 iPad 模拟器上实测到过：一个当天注销的账号，
 * token 拿去调 /me 和 /sync/push 全部通过。后果是那台设备能把本地数据推回云端，
 * 把「已删除」的数据复活——我们对应用商店和隐私政策承诺的删除就成了假的。
 *
 * 放在数据面（pull/push/patchMe）而不是鉴权中间件里，是因为中间件对每个请求都要
 * 多查一次用户文档；这三个入口本来就要查 profile，顺手判断不额外花钱。
 */
export function accountBlocked(
  profile?: { banned?: boolean; deleted?: boolean } | null,
): Res | null {
  if (!profile) return null;
  // 封禁沿用原来的通用 401（客户端按「登录已过期」处理），不改既有行为
  if (profile.banned) return json(401, { error: 'unauthorized' });
  // 注销给一个明确的码，客户端好说人话——它跟「过期」不是一回事，重登也没用
  if (profile.deleted) return json(401, { error: 'account_deleted' });
  return null;
}
