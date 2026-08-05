// 逆地理编码兜底：手机系统自带的反地理编码（Android Geocoder）依赖 Google
// 服务，没装 Google 服务的安卓机（国内大多数机型）直接查不到地名。这里代理
// 高德 Web 服务 API 的逆地理编码接口，key 只留在后端，不下发到客户端。
import { AMAP_KEY } from '../config';
import { bad, ok, Req } from '../http';

/** GET /api/geocode/reverse?lat=..&lng=.. */
export async function reverseGeocode(req: Req) {
  if (!AMAP_KEY) return bad('geocode_not_configured');

  const lat = Number(req.query.lat);
  const lng = Number(req.query.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return bad('invalid_coords');

  const url =
    `https://restapi.amap.com/v3/geocode/regeo?key=${AMAP_KEY}` +
    `&location=${lng},${lat}&extensions=base`;

  let data: any;
  try {
    const res = await fetch(url);
    data = await res.json();
  } catch {
    return bad('geocode_upstream_error');
  }
  if (data?.status !== '1' || !data.regeocode) return bad('geocode_no_match');

  // 城市名优先，取不到就逐级退：区县 → 省 → 国家；高德个别字段偶尔给空数组
  const c = data.regeocode.addressComponent ?? {};
  const name = [c.city, c.district, c.province, c.country]
    .map((v) => (Array.isArray(v) ? v[0] : v))
    .find((s) => typeof s === 'string' && s.length > 0);
  if (!name) return bad('geocode_no_match');
  return ok({ name });
}
