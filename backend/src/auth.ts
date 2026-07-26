// 取当前登录用户 uid。
// 方案 A（推荐）：用 CloudBase 内置邮箱认证。App 端用 CloudBase SDK 登录后，
// 调用云函数会带上访问令牌（Authorization: Bearer <access_token>），这里校验并取 uid。
//
// mock 模式：从 x-mock-uid 头取（默认 u_dev），本地开发无需真实登录。

import { ENV_ID, IS_MOCK } from './config';
import { Req } from './http';

function bearer(req: Req): string | null {
  const h = req.headers['authorization'] || req.headers['Authorization'];
  if (!h) return null;
  const m = /^Bearer\s+(.+)$/i.exec(h);
  return m ? m[1] : null;
}

let _authApp: any = null;
function authApp() {
  if (!_authApp) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const cloudbase = require('@cloudbase/node-sdk');
    _authApp = cloudbase.init({ env: ENV_ID });
  }
  return _authApp;
}

/** 返回 uid；未登录返回 null */
export async function getUid(req: Req): Promise<string | null> {
  if (IS_MOCK) {
    return req.headers['x-mock-uid'] || 'u_dev';
  }
  const token = bearer(req);
  if (!token) return null;
  try {
    // TODO: 按 CloudBase 当前 SDK 校验访问令牌并取 uid。
    // 参考：app.auth().getEndUserInfo(token) 或 app.auth().verifyToken(token)
    // 首次部署后按控制台/SDK 实际方法名对齐；下面为占位实现。
    const app = authApp();
    const info = await app.auth().getEndUserInfo(token);
    return info?.userInfo?.uid || info?.uid || null;
  } catch {
    return null;
  }
}
