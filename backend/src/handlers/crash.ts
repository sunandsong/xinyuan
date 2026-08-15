// 崩溃上报：客户端把 Dart 层未捕获异常和「上次异常退出」攒在本地，下次启动补发。
// 走 public 路由不校验登录——崩溃很可能发生在登录之前（启动崩、未登录预览模式崩），
// 要求登录反而把最该看到的那批崩溃挡在门外了。
import { createHash } from 'crypto';
import { getDb } from '../db';
import { bad, ok, Req } from '../http';
import { CrashInfo } from '../types';

const MAX_BATCH = 20;
const MAX_STACK = 8000;

/** 认得的崩溃种类；客户端加新种类时这里也得加，否则会被兜底成 dart_error（踩过一次） */
const KINDS = new Set(['dart_error', 'native_crash', 'abnormal_exit']);

/** 指纹：异常类型 + 堆栈前几帧。同一个 bug 崩一万次要归成一条，不然没法看。
 * 去掉行内的十六进制地址和纯数字，避免同一处崩溃因为地址不同被拆成多条。 */
export function fingerprint(type: string, stack: string): string {
  const head = stack
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean)
    .slice(0, 5)
    .map((l) => l.replace(/0x[0-9a-f]+/gi, '').replace(/\d+/g, ''))
    .join('|');
  return createHash('sha1').update(`${type}\n${head}`).digest('hex').slice(0, 24);
}

function clean(v: unknown, max = 500): string {
  return typeof v === 'string' ? v.slice(0, max) : '';
}

/** POST /api/crash —— 批量上报，一次最多 20 条 */
export async function report(req: Req) {
  const raw = req.body?.crashes;
  if (!Array.isArray(raw) || raw.length === 0) return bad('crashes_required');

  const db = getDb();
  let accepted = 0;

  for (const c of raw.slice(0, MAX_BATCH)) {
    if (!c || typeof c !== 'object') continue;
    const type = clean(c.type, 200);
    if (!type) continue;

    const info: CrashInfo = {
      kind: KINDS.has(c.kind) ? c.kind : 'dart_error',
      type,
      message: clean(c.message, 1000),
      stack: clean(c.stack, MAX_STACK),
      appVersion: clean(c.appVersion, 32),
      platform: clean(c.platform, 32),
      osVersion: clean(c.osVersion, 200),
      at: typeof c.at === 'number' ? c.at : Date.now(),
      account: clean(c.account, 64),
    };

    try {
      await db.recordCrash(fingerprint(info.type, info.stack), info);
      accepted++;
    } catch {
      // 单条失败不拖累整批：崩溃上报本身绝不能再制造错误
    }
  }

  return ok({ accepted });
}
