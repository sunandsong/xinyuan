// 本地开发服务器：只是把云函数的 handler 挂到本机 HTTP 端口上，
// 数据照样读写 CloudBase（需要 CLOUDBASE_ENV_ID + 已 tcb login）。
// 运行：npm run dev  → http://127.0.0.1:8787
import http from 'http';
import { ENV_ID } from './config';
import { Req } from './http';
import { handle } from './router';

const PORT = Number(process.env.PORT || 8787);

const server = http.createServer((rawReq, rawRes) => {
  const chunks: Buffer[] = [];
  rawReq.on('data', (c) => chunks.push(c));
  rawReq.on('end', async () => {
    const url = new URL(rawReq.url || '/', `http://localhost`);
    const query: Record<string, string> = {};
    url.searchParams.forEach((v, k) => (query[k] = v));
    const headers: Record<string, string> = {};
    for (const [k, v] of Object.entries(rawReq.headers)) headers[k.toLowerCase()] = String(v);
    let body: any;
    if (chunks.length) {
      const text = Buffer.concat(chunks).toString('utf8');
      try {
        body = JSON.parse(text);
      } catch {
        body = text;
      }
    }
    const req: Req = { method: (rawReq.method || 'GET').toUpperCase(), path: url.pathname, query, headers, body };
    const res = await handle(req);
    rawRes.writeHead(res.statusCode, res.headers);
    rawRes.end(res.body);
    console.log(`${req.method} ${req.path} -> ${res.statusCode}`);
  });
});

server.listen(PORT, () => console.log(`本地后端 http://127.0.0.1:${PORT} → CloudBase ${ENV_ID || '(未设置 CLOUDBASE_ENV_ID)'}`));
