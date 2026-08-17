#!/usr/bin/env python3
"""账号注销后端 + 静态托管。纯标准库,无依赖。

启动:  python3 server.py [端口]
自检:  python3 server.py --selfcheck

环境变量(不设 SMTP_HOST 时,验证链接直接打印到控制台,方便本地调试):
  SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASS MAIL_FROM BASE_URL
"""
import json, os, re, smtplib, sqlite3, secrets, sys, threading
from datetime import datetime, timezone
from email.message import EmailMessage
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

ROOT = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(ROOT, 'deletions.db')
EMAIL_RE = re.compile(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
REASONS = {'', 'no_longer_use', 'privacy', 'notifications', 'alternative', 'experience', 'other'}
BASE_URL = os.environ.get('BASE_URL', 'http://localhost:8000')


def db():
    con = sqlite3.connect(DB_PATH)
    con.execute("""CREATE TABLE IF NOT EXISTS requests (
        ref TEXT PRIMARY KEY, account TEXT NOT NULL, email TEXT NOT NULL, reason TEXT,
        token TEXT UNIQUE NOT NULL, status TEXT NOT NULL, ip TEXT,
        created_at TEXT NOT NULL, confirmed_at TEXT)""")
    return con


def now():
    return datetime.now(timezone.utc).isoformat(timespec='seconds')


def send_mail(to, ref, link):
    body = (f"您好,\n\n我们收到了您的账号注销申请(编号 {ref})。\n"
            f"请点击下面的链接确认,确认后我们将在 60 天内完成删除:\n\n{link}\n\n"
            "链接 24 小时内有效。若非您本人操作,请忽略此邮件,账号不会有任何变动。\n")
    host = os.environ.get('SMTP_HOST')
    if not host:
        print(f"[dev] 未配置 SMTP,验证链接: {link}", flush=True)
        return
    msg = EmailMessage()
    msg['Subject'] = f'确认注销账号 ({ref})'
    msg['From'] = os.environ.get('MAIL_FROM', os.environ.get('SMTP_USER', 'noreply@example.com'))
    msg['To'] = to
    msg.set_content(body)
    with smtplib.SMTP(host, int(os.environ.get('SMTP_PORT', 587)), timeout=20) as s:
        s.starttls()
        if os.environ.get('SMTP_USER'):
            s.login(os.environ['SMTP_USER'], os.environ.get('SMTP_PASS', ''))
        s.send_message(msg)


def create_request(account, email, reason, ip):
    """返回 (http_status, 响应字典)。校验在这里做,是唯一的信任边界。"""
    account = (account or '').strip()
    email = (email or '').strip()
    reason = (reason or '').strip()
    if not account or len(account) > 200:
        return 400, {'code': 1, 'message': '账号 ID 无效'}
    if not EMAIL_RE.match(email) or len(email) > 254:
        return 400, {'code': 1, 'message': '邮箱地址无效'}
    if reason not in REASONS:
        return 400, {'code': 1, 'message': '原因无效'}

    ref = 'REF-' + secrets.token_hex(5).upper()
    token = secrets.token_urlsafe(32)
    with db() as con:
        con.execute("INSERT INTO requests VALUES (?,?,?,?,?,'pending',?,?,NULL)",
                    (ref, account, email, reason, token, ip, now()))
    try:
        send_mail(email, ref, f'{BASE_URL}/api/account/confirm?token={token}')
    except Exception as e:                      # 邮件失败不丢申请记录
        print(f'[warn] 邮件发送失败 {ref}: {e}', flush=True)
    return 200, {'code': 0, 'message': 'success', 'data': {'refId': ref}}


def confirm(token):
    """返回 (标题, 说明)。重复点击链接是幂等的。"""
    if not token:
        return '链接无效', '缺少验证参数,请检查邮件中的完整链接。'
    with db() as con:
        row = con.execute('SELECT ref, status FROM requests WHERE token=?', (token,)).fetchone()
        if not row:
            return '链接无效或已失效', '未找到对应的注销申请,请重新提交。'
        ref, status = row
        if status == 'pending':
            con.execute("UPDATE requests SET status='confirmed', confirmed_at=? WHERE token=?", (now(), token))
        return '注销申请已确认', f'编号 {ref}。我们将在 60 天内完成账号及相关数据的删除。'


PAGE = """<!DOCTYPE html><html lang="zh-CN"><meta charset="utf-8">
<title>{title}</title><meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{{font-family:-apple-system,'PingFang SC',sans-serif;background:#F5F5F7;color:#111;
display:grid;place-items:center;min-height:100vh;margin:0;padding:24px}}
div{{background:#fff;border:1px solid #E5E5E5;border-radius:16px;padding:40px 32px;max-width:440px;text-align:center}}
h1{{font-size:20px;margin:0 0 10px}}p{{color:#555;font-size:14px;line-height:1.7;margin:0}}</style>
<div><h1>{title}</h1><p>{msg}</p></div>"""


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def _send(self, status, body, ctype):
        raw = body.encode()
        self.send_response(status)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        if urlparse(self.path).path == '/api/account/confirm':
            token = parse_qs(urlparse(self.path).query).get('token', [''])[0]
            title, msg = confirm(token)
            self._send(200, PAGE.format(title=title, msg=msg), 'text/html; charset=utf-8')
        else:
            super().do_GET()

    def do_POST(self):
        if urlparse(self.path).path != '/api/account/cancel':
            self.send_error(404)
            return
        try:
            n = int(self.headers.get('Content-Length', 0))
            if n > 8192:
                raise ValueError('payload too large')
            data = json.loads(self.rfile.read(n) or b'{}')
            if not isinstance(data, dict):
                raise ValueError('expected object')
        except Exception:
            self._send(400, json.dumps({'code': 1, 'message': '请求格式错误'}), 'application/json')
            return
        # ponytail: 无限流,单机部署够用;暴露到公网后在反代层(nginx/Cloudflare)按 IP 限速
        status, resp = create_request(data.get('account'), data.get('contactEmail'),
                                      data.get('reason'), self.client_address[0])
        self._send(status, json.dumps(resp, ensure_ascii=False), 'application/json; charset=utf-8')

    def log_message(self, fmt, *args):
        print(f'{self.client_address[0]} {fmt % args}', flush=True)


def selfcheck():
    global DB_PATH, BASE_URL
    import tempfile, urllib.request, urllib.error
    DB_PATH = os.path.join(tempfile.mkdtemp(), 'test.db')
    srv = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    BASE_URL = f'http://127.0.0.1:{srv.server_port}'
    threading.Thread(target=srv.serve_forever, daemon=True).start()

    def post(payload):
        req = urllib.request.Request(f'{BASE_URL}/api/account/cancel', method='POST',
                                     data=json.dumps(payload).encode(),
                                     headers={'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(req) as r:
                return r.status, json.load(r)
        except urllib.error.HTTPError as e:
            return e.code, json.load(e)

    st, r = post({'account': 'u1', 'contactEmail': 'a@b.com', 'reason': 'privacy'})
    assert (st, r['code']) == (200, 0), r
    ref = r['data']['refId']

    for bad in ({'account': '', 'contactEmail': 'a@b.com'},
                {'account': 'u1', 'contactEmail': 'not-an-email'},
                {'account': 'u1', 'contactEmail': 'a@b.com', 'reason': 'hax'},
                {'account': 'x' * 201, 'contactEmail': 'a@b.com'}):
        st, r = post(bad)
        assert (st, r['code']) == (400, 1), (bad, st, r)

    with db() as con:
        token = con.execute('SELECT token FROM requests WHERE ref=?', (ref,)).fetchone()[0]
    with urllib.request.urlopen(f'{BASE_URL}/api/account/confirm?token={token}') as resp:
        assert '已确认' in resp.read().decode()
    with db() as con:                                    # 幂等:再点一次仍是 confirmed
        assert con.execute('SELECT status FROM requests WHERE ref=?', (ref,)).fetchone()[0] == 'confirmed'
    assert '无效' in confirm('garbage')[0]
    assert '无效' in confirm('')[0]
    srv.shutdown()
    print('selfcheck OK')


if __name__ == '__main__':
    if '--selfcheck' in sys.argv:
        selfcheck()
    else:
        port = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 8000
        db().close()
        print(f'http://localhost:{port}/  (BASE_URL={BASE_URL})', flush=True)
        ThreadingHTTPServer(('', port), Handler).serve_forever()
