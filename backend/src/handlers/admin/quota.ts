// 管理端额度查询：调腾讯云 TCB DescribeQuotaData 查本月读/写/函数调用/存储用量，
// 并结合套餐信息折算资源点总额/已用/预估耗尽时间。
import * as crypto from 'crypto';
import { ENV_ID, TC_SECRET_ID, TC_SECRET_KEY } from '../../config';
import { ok, Req } from '../../http';

const HOST = 'tcb.tencentcloudapi.com';
const SERVICE = 'tcb';
const REGION = 'ap-shanghai';
const VERSION = '2018-06-08';

/** 套餐 → 每月资源点额度（2026 免费体验版 3000 点/月） */
const PACKAGE_MONTHLY_CREDITS: Record<string, { name: string; credits: number }> = {
  baas_trial: { name: '免费体验版', credits: 3000 },
};

/** 资源点折算：跟 CloudBase 资源点价格文档对齐（200点/万次 调用类） */
const POINTS_PER_10K = 200;
const STORAGE_POINTS_PER_GB_DAY = 40;

function sha256Hex(s: string): string {
  return crypto.createHash('sha256').update(s, 'utf8').digest('hex');
}
function hmac(key: string | Buffer, msg: string): Buffer {
  return crypto.createHmac('sha256', key).update(msg, 'utf8').digest();
}

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

const METRICS: Record<string, string> = {
  dbRead: 'DbReadpkg',
  dbWrite: 'DbWritepkg',
  functionInvoke: 'FunctionInvocationpkg',
  storage: 'StorageSizepkg',
};

function monthRange(): { start: string; end: string } {
  const now = new Date();
  const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const fmt = (d: Date) => d.toISOString().slice(0, 19).replace('T', ' ');
  return { start: fmt(start), end: fmt(now) };
}

function daysElapsedInMonth(): number {
  return new Date().getDate();
}

function parseLimit(resp: any): number | null {
  for (const raw of [resp?.Limit, resp?.SubValue]) {
    const n = Number(raw);
    if (Number.isFinite(n) && n > 0) return n;
  }
  return null;
}

/** 把各指标用量折算成资源点（估算，供仪表盘看趋势） */
function metricPoints(key: string, used: number, daysElapsed: number): number {
  if (used <= 0) return 0;
  if (key === 'storage') return (used / 1024) * daysElapsed * STORAGE_POINTS_PER_GB_DAY;
  return (used / 10_000) * POINTS_PER_10K;
}

async function fetchPackageId(): Promise<string | null> {
  try {
    const resp = await tcbRequest('DescribeBillingInfo', { EnvId: ENV_ID });
    const pkg = resp?.EnvBillingInfoList?.[0]?.PackageId;
    return typeof pkg === 'string' ? pkg : null;
  } catch {
    return null;
  }
}

/** GET /admin/quota */
export async function quota(_req: Req) {
  if (!TC_SECRET_ID || !TC_SECRET_KEY) return ok({ available: false, reason: 'no_secret' });

  const { start, end } = monthRange();
  const daysElapsed = daysElapsedInMonth();
  try {
    const [packageId, ...metricResps] = await Promise.all([
      fetchPackageId(),
      ...Object.values(METRICS).map((metricName) =>
        tcbRequest('DescribeQuotaData', { EnvId: ENV_ID, MetricName: metricName, StartTime: start, EndTime: end }),
      ),
    ]);

    const pkgMeta = (packageId && PACKAGE_MONTHLY_CREDITS[packageId]) || null;
    const envCredits = Number(process.env.QUOTA_MONTHLY_CREDITS);
    const monthlyCredits =
      (Number.isFinite(envCredits) && envCredits > 0 ? envCredits : null) ?? pkgMeta?.credits ?? null;

    const metrics: Record<string, { used: number | null; limit: number | null; points: number | null }> = {};
    let totalPoints = 0;
    Object.keys(METRICS).forEach((key, i) => {
      const resp = metricResps[i];
      const usedNum = Number(resp?.Value);
      const used = Number.isFinite(usedNum) ? usedNum : null;
      const points = used != null ? Math.round(metricPoints(key, used, daysElapsed) * 10) / 10 : null;
      if (points) totalPoints += points;
      metrics[key] = { used, limit: parseLimit(resp), points };
    });

    const summary =
      monthlyCredits != null
        ? {
            limit: monthlyCredits,
            used: Math.round(totalPoints * 10) / 10,
            unit: '点',
            packageId: packageId ?? undefined,
            packageName: pkgMeta?.name,
          }
        : null;

    return ok({
      available: true,
      package: packageId ? { id: packageId, name: pkgMeta?.name } : null,
      summary,
      metrics,
    });
  } catch (e: any) {
    return ok({ available: false, reason: String(e?.message ?? e) });
  }
}
