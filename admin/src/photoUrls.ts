import { api } from './api';

const cache = new Map<string, string>();
const inflight = new Map<string, Promise<Record<string, string>>>();

/** 云存储稳定链接（wishes/、content/）才需要换临时签名；外链直用 */
export function isCloudPhotoUrl(url: string): boolean {
  try {
    const path = decodeURIComponent(new URL(url).pathname.replace(/^\//, ''));
    return path.startsWith('wishes/') || path.startsWith('content/');
  } catch {
    return false;
  }
}

/** 批量把稳定云存储链接换成可访问的临时链接（跟 App 端 freshPhotoUrl 同理） */
export async function freshPhotoUrls(stored: string[]): Promise<Record<string, string>> {
  const keys = [...new Set(stored.map((u) => u.split('?')[0]).filter(Boolean))];
  const missing = keys.filter((k) => !cache.has(k));
  if (missing.length === 0) {
    const out: Record<string, string> = {};
    for (const k of keys) {
      const v = cache.get(k);
      if (v) out[k] = v;
    }
    return out;
  }

  const batchKey = missing.sort().join('|');
  if (!inflight.has(batchKey)) {
    inflight.set(
      batchKey,
      api
        .post('/admin/photo-urls', { urls: missing })
        .then((r) => (r.urls ?? {}) as Record<string, string>)
        .catch(() => ({} as Record<string, string>))
        .finally(() => inflight.delete(batchKey)),
    );
  }
  const resolved = await inflight.get(batchKey)!;
  for (const [k, v] of Object.entries(resolved)) cache.set(k, v);

  const out: Record<string, string> = {};
  for (const k of keys) {
    const v = cache.get(k);
    if (v) out[k] = v;
  }
  return out;
}

export async function freshPhotoUrl(stored: string): Promise<string | null> {
  if (!stored) return null;
  if (!isCloudPhotoUrl(stored)) return stored;
  const key = stored.split('?')[0];
  const m = await freshPhotoUrls([key]);
  return m[key] ?? null;
}
