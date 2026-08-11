// 管理端额度查询：调腾讯云 TCB DescribeQuotaData 查本月读/写/函数调用/存储用量。
// 密钥未配置、接口报错、字段对不上——一律 available:false，绝不 500：
// 这是仪表盘上的可选展示项，查不到就前端显示"未配置密钥"，不能拖垮管理端。
import * as crypto from 'crypto';
import { ENV_ID, TC_SECRET_ID, TC_SECRET_KEY } from '../../config';
import { ok, Req } from '../../http';

const HOST = 'tcb.tencentcloudapi.com';
const SERVICE = 'tcb';
const REGION = 'ap-shanghai';
const VERSION = '2018-06-08';

function sha256Hex(s: string): string {
  return crypto.createHash('sha256').update(s, 'utf8').digest('hex');
}
function hmac(key: string | Buffer, msg: string): Buffer {
  return crypto.createHmac('sha256', key).update(msg, 'utf8').digest();
}

/** 腾讯云 API 3.0 TC3-HMAC-SHA256 通用签名 + 请求。约 40 行，手写不引 SDK。 */
async function tcbRequest(action: string, payload: Record<string, unknown>): Promise<any> {
  const timestamp = Math.floor(Date.now() / 1000);
  const date = new Date(timestamp * 1000).toISOString().slice(0, 10);
  const body = JSON.stringify(payload);

  const signedHeaders = 'content-type;host;x-tc-action';
  const canonicalHeaders = `content-type:application/json\nhost:${HOST}\nx-tc-action:${action.toLowerCase()}\n`;
  const canonicalRequest = ['POST', '/', '', canonicalHeaders, signedHeaders, sha256Hex(body)].join('\n');

  const credentialScope = `${date}/${SERVICE}/tc3_request`;
  const stringToSign = [
    'TC3-HMAC-SHA256',
    String(timestamp),
    credentialScope,
    sha256Hex(canonicalRequest),
  ].join('\n');

  const secretDate = hmac(`TC3${TC_SECRET_KEY}`, date);
  const secretService = hmac(secretDate, SERVICE);
  const secretSigning = hmac(secretService, 'tc3_request');
  const signature = hmac(secretSigning, stringToSign).toString('hex');

  const authorization =
    `TC3-HMAC-SHA256 Credential=${TC_SECRET_ID}/${credentialScope}, ` +
    `SignedHeaders=${signedHeaders}, Signature=${signature}`;

  const resp = await fetch(`https://${HOST}/`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      host: HOST,
      authorization,
      'x-tc-action': action,
      'x-tc-timestamp': String(timestamp),
      'x-tc-version': VERSION,
      'x-tc-region': REGION,
    },
    body,
  });
  const json: any = await resp.json();
  if (json?.Response?.Error) throw new Error(`${json.Response.Error.Code}: ${json.Response.Error.Message}`);
  return json?.Response;
}

/** 指标名对不上、拿不到就当没有——TCB 控制台用这几个 MetricName 查用量 */
const METRICS: Record<string, string> = {
  dbRead: 'DbReadpkg',
  dbWrite: 'DbWritepkg',
  functionInvoke: 'FunctionInvocationpkg',
  storage: 'StorageSizepkg',
};

/** 本月起 ~ 现在，'YYYY-MM-DD HH:mm:ss'（UTC） */
function monthRange(): { start: string; end: string } {
  const now = new Date();
  const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const fmt = (d: Date) => d.toISOString().slice(0, 19).replace('T', ' ');
  return { start: fmt(start), end: fmt(now) };
}

/** GET /admin/quota —— 本月资源用量骨架，密钥未配/调用失败一律 available:false，不是 500 */
export async function quota(_req: Req) {
  if (!TC_SECRET_ID || !TC_SECRET_KEY) return ok({ available: false, reason: 'no_secret' });

  const { start, end } = monthRange();
  try {
    const metrics: Record<string, { used: number | null; limit: number | null }> = {};
    for (const [key, metricName] of Object.entries(METRICS)) {
      const resp = await tcbRequest('DescribeQuotaData', {
        EnvId: ENV_ID,
        MetricName: metricName,
        StartTime: start,
        EndTime: end,
      });
      // 实测响应是单值 {MetricName,RequestId,SubValue,Value}，不是数组/数据集
      // （曾按 QuotaDataSet/Data 数组猜测过，用临时密钥实测校准过来，见 task-8-report.md）。
      const usedNum = Number(resp?.Value);
      metrics[key] = {
        used: Number.isFinite(usedNum) ? usedNum : null,
        limit: resp?.Limit ?? null,
      };
    }
    return ok({ available: true, metrics });
  } catch (e: any) {
    return ok({ available: false, reason: String(e?.message ?? e) });
  }
}
