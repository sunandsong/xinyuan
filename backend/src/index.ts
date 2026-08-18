// CloudBase 云函数入口（HTTP 访问服务）。
// 部署后配置 HTTP 触发，路由 /api/* 与 /s/* 打到本函数。
import { runCleanup } from './handlers/cleanup';
import { Req } from './http';
import { handle } from './router';

function lower(headers: Record<string, string>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const k of Object.keys(headers || {})) out[k.toLowerCase()] = headers[k];
  return out;
}

function toReq(event: any): Req {
  const method = String(event.httpMethod || event.method || 'GET').toUpperCase();
  const path = String(event.path || event.rawPath || '/').split('?')[0];
  const query = event.queryStringParameters || event.queryString || {};
  const headers = lower(event.headers || {});
  let body: any;
  if (event.body) {
    const text = event.isBase64Encoded ? Buffer.from(event.body, 'base64').toString('utf8') : event.body;
    try {
      body = JSON.parse(text);
    } catch {
      body = text;
    }
  }
  return { method, path, query, headers, body };
}

export async function main(event: any) {
  // 定时触发器的事件长这样：{ Type: 'Timer', TriggerName, Time }——没有 httpMethod/path，
  // 塞进 HTTP 路由只会得到一个 404。单独认出来，走数据留存清理。
  if (event && event.Type === 'Timer') {
    const result = await runCleanup();
    console.log('[cleanup]', JSON.stringify(result));
    return result;
  }
  const res = await handle(toReq(event));
  return { statusCode: res.statusCode, headers: res.headers, body: res.body, isBase64Encoded: false };
}
