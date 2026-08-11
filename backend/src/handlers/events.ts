import { COL } from '../config';
import { getDb } from '../db';
import { bad, ok, Req } from '../http';

const MAX_EVENTS = 50;

/** POST /api/events —— 行为埋点，批量上报，一次最多 50 条；写库失败也吞掉（埋点丢了就丢了） */
export async function track(req: Req, uid: string) {
  const raw = req.body?.events;
  if (!Array.isArray(raw) || raw.length === 0) return bad('events_required');

  const items = raw
    .slice(0, MAX_EVENTS)
    .filter((e) => e && typeof e.event === 'string' && e.event.trim());

  const db = getDb();
  try {
    await Promise.all(
      items.map((e) =>
        db.upsertDoc(COL.events, undefined, {
          uid,
          event: e.event,
          props: e.props ?? null,
          at: typeof e.at === 'number' ? e.at : Date.now(),
        }),
      ),
    );
  } catch {}

  return ok({ accepted: items.length });
}
