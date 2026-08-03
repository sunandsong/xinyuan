// 取当前登录用户 uid：验证后端自签的 JWT（Authorization: Bearer <token>）。
import { JWT_SECRET } from './config';
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
  if (!token) return null;
  const payload = verifyJwt(token, JWT_SECRET);
  return payload?.uid ? String(payload.uid) : null;
}
