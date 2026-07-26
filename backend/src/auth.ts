// 取当前登录用户 uid：验证后端自签的 JWT（Authorization: Bearer <token>）。
// mock 模式额外允许 x-mock-uid 头，方便本地无登录调试。
import { IS_MOCK, JWT_SECRET } from './config';
import { Req } from './http';
import { verifyJwt } from './jwt';

function bearer(req: Req): string | null {
  const h = req.headers['authorization'] || req.headers['Authorization'];
  if (!h) return null;
  const m = /^Bearer\s+(.+)$/i.exec(h);
  return m ? m[1] : null;
}

/** 返回 uid；未登录返回 null */
export async function getUid(req: Req): Promise<string | null> {
  const token = bearer(req);
  if (token) {
    const payload = verifyJwt(token, JWT_SECRET);
    if (payload?.uid) return String(payload.uid);
  }
  if (IS_MOCK && req.headers['x-mock-uid']) return req.headers['x-mock-uid'];
  return null;
}
