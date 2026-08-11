// 与云函数入口/本地服务器解耦的请求-响应抽象 + 极简路由。

export interface Req {
  method: string;
  path: string; // 如 /api/sync/pull
  query: Record<string, string>;
  headers: Record<string, string>;
  body: any; // 已解析的 JSON（可能为 undefined）
}

export interface Res {
  statusCode: number;
  headers: Record<string, string>;
  body: string;
}

// 跨域头：管理端是独立前端页面，统一在这里加一次，别每个 handler 重复。
export const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type,x-admin-key,authorization',
  'Access-Control-Allow-Methods': 'GET,POST,DELETE,PATCH,OPTIONS',
};

export function json(statusCode: number, data: unknown): Res {
  return {
    statusCode,
    headers: { 'content-type': 'application/json; charset=utf-8', ...CORS_HEADERS },
    body: JSON.stringify(data),
  };
}

export function ok(data: unknown = { ok: true }): Res {
  return json(200, data);
}
export function bad(msg: string): Res {
  return json(400, { error: msg });
}
export function unauthorized(): Res {
  return json(401, { error: 'unauthorized' });
}
export function forbidden(err: string): Res {
  return json(403, { error: err });
}
export function notFound(): Res {
  return json(404, { error: 'not_found' });
}
export function serverError(msg = 'internal_error'): Res {
  return json(500, { error: msg });
}

export type Handler = (req: Req) => Promise<Res>;
export interface Route {
  method: string;
  pattern: RegExp;
  keys: string[];
  handler: (req: Req, params: Record<string, string>) => Promise<Res>;
}

/** 把 "/s/:code" 编译成正则 + 参数名 */
export function route(
  method: string,
  path: string,
  handler: (req: Req, params: Record<string, string>) => Promise<Res>,
): Route {
  const keys: string[] = [];
  const pattern = new RegExp(
    '^' +
      path.replace(/:[^/]+/g, (m) => {
        keys.push(m.slice(1));
        return '([^/]+)';
      }) +
      '/?$',
  );
  return { method, pattern, keys, handler };
}

/** 命中返回 Res；无匹配返回 null（由调用方决定 404） */
export async function dispatch(routes: Route[], req: Req): Promise<Res | null> {
  for (const r of routes) {
    if (r.method !== req.method) continue;
    const m = req.path.match(r.pattern);
    if (!m) continue;
    const params: Record<string, string> = {};
    r.keys.forEach((k, i) => (params[k] = decodeURIComponent(m[i + 1])));
    return r.handler(req, params);
  }
  return null;
}
