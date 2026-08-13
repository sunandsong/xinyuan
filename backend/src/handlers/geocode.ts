// 逆地理编码兜底：手机系统自带的反地理编码（Android Geocoder）依赖 Google
// 服务，没装 Google 服务的安卓机（国内大多数机型）直接查不到地名。这里代理
// 高德 Web 服务 API 的逆地理编码接口，key 只留在后端，不下发到客户端。
import { amapConfigured, reverseGeocodeName } from '../amap';
import { bad, ok, Req } from '../http';

/** GET /api/geocode/reverse?lat=..&lng=.. */
export async function reverseGeocode(req: Req) {
  if (!amapConfigured()) return bad('geocode_not_configured');

  const lat = Number(req.query.lat);
  const lng = Number(req.query.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return bad('invalid_coords');

  try {
    const name = await reverseGeocodeName(lat, lng);
    if (!name) return bad('geocode_no_match');
    return ok({ name });
  } catch {
    return bad('geocode_upstream_error');
  }
}
