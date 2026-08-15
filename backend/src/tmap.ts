import { TMAP_KEY } from './config';

export function tmapConfigured(): boolean {
  return Boolean(TMAP_KEY);
}

/** 腾讯 province → 跟种子数据一致的省份简称 */
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

export async function tmapFetch(path: string, params: Record<string, string>): Promise<any> {
  const qs = new URLSearchParams({ ...params, key: TMAP_KEY });
  const res = await fetch(`https://apis.map.qq.com${path}?${qs}`);
  return res.json();
}

/** App 端逆地理：返回地名（城市/区县优先）。腾讯坐标顺序是 lat,lng（纬度在前） */
export async function reverseGeocodeName(lat: number, lng: number): Promise<string | null> {
  const data = await tmapFetch('/ws/geocoder/v1/', {
    location: `${lat},${lng}`,
  });
  if (data?.status !== 0 || !data.result) return null;
  const c = data.result.address_component ?? {};
  const name = [c.city, c.district, c.province]
    .find((s: unknown) => typeof s === 'string' && s.length > 0);
  return typeof name === 'string' ? name : null;
}
