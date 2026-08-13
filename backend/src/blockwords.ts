// 屏蔽词：标题/昵称命中就不放行。词表百级数据量，每次请求现查一次即可，
// 不做进程内缓存——缓存要处理失效，比直接查一次更麻烦（YAGNI）。
// 调用方在一次请求里只 loadBlockwords() 一次，多条记录复用同一份词表。
import { getDb } from './db';

export async function loadBlockwords(): Promise<string[]> {
  try {
    const { items } = await getDb().listDocs('blockwords', { limit: 2000 });
    return items.map((d: any) => String(d.word ?? '')).filter(Boolean);
  } catch {
    return [];
  }
}

/** 包含式匹配：title/nickname 里含任一屏蔽词就算命中 */
export function isBlocked(text: string, words: string[]): boolean {
  return words.some((w) => text.includes(w));
}

/** 昵称命中屏蔽词时替换为脱敏展示名 */
export function sanitizeNickname(nickname: string, uid: string, words: string[]): string {
  return isBlocked(nickname, words) ? '用户' + uid.slice(-4) : nickname;
}
