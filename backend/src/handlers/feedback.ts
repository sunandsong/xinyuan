import { getDb } from '../db';
import { bad, ok, Req } from '../http';

/** POST /api/feedback —— 意见反馈，存进 feedback 表，人工在 CloudBase 控制台看 */
export async function submitFeedback(req: Req, uid: string) {
  const content = typeof req.body?.content === 'string' ? req.body.content.trim() : '';
  if (!content) return bad('content_required');

  const db = getDb();
  await db.createFeedback({
    _id: `fb_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`,
    uid,
    content: content.slice(0, 1000),
    createdAt: Date.now(),
  });
  return ok({ ok: true });
}
