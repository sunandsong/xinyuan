import { AMAP_KEY } from './config';

export function amapConfigured(): boolean {
  return Boolean(AMAP_KEY);
}

/** 高德 pname → 跟种子数据一致的省份简称 */
export function normProvince(raw: string): string {
  return raw
    .replace(/特别行政区$/, '')
    .replace(/维吾尔自治区$/, '')
    .replace(/壮族自治区$/, '')
    .replace(/回族自治区$/, '')
    .replace(/自治区$/, '')
    .replace(/省$/, '')
    .replace(/市$/, '');
}

export async function amapFetch(path: string, params: Record<string, string>): Promise<any> {
  const qs = new URLSearchParams({ ...params, key: AMAP_KEY });
  const res = await fetch(`https://restapi.amap.com${path}?${qs}`);
  return res.json();
}

/** App 端逆地理：返回地名（城市/区县优先） */
export async function reverseGeocodeName(lat: number, lng: number): Promise<string | null> {
  const data = await amapFetch('/v3/geocode/regeo', {
    location: `${lng},${lat}`,
    extensions: 'base',
  });
  if (data?.status !== '1' || !data.regeocode) return null;
  const c = data.regeocode.addressComponent ?? {};
  const name = [c.city, c.district, c.province, c.country]
    .map((v: unknown) => (Array.isArray(v) ? v[0] : v))
    .find((s: unknown) => typeof s === 'string' && s.length > 0);
  return typeof name === 'string' ? name : null;
}
