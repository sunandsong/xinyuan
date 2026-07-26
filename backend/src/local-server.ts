// 本地开发服务器（MODE=mock，不打云、不耗额度）。
// 运行：npm run dev  → http://127.0.0.1:8787
// 鉴权用 x-mock-uid 头模拟登录用户（默认 u_dev）。
import http from 'http';
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

server.listen(PORT, () => console.log(`[mock] 本地后端 http://127.0.0.1:${PORT}  (MODE=mock)`));
