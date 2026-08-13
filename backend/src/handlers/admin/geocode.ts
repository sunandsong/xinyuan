import { AMAP_JS_CODE, AMAP_KEY } from '../../config';
import { amapConfigured, amapFetch, normProvince } from '../../amap';
import { bad, ok, Req } from '../../http';

/** GET /admin/map-config —— 管理端加载高德 JS 地图用 */
export async function mapConfig(_req: Req) {
  if (!amapConfigured()) return ok({ available: false });
  return ok({
    available: true,
    key: AMAP_KEY,
    securityCode: AMAP_JS_CODE || undefined,
  });
}

/** GET /admin/geocode/search?keyword=故宫 */
export async function placeSearch(req: Req) {
  if (!amapConfigured()) return bad('geocode_not_configured');
  const keyword = String(req.query.keyword ?? '').trim();
  if (!keyword) return bad('invalid_keyword');

  let data: any;
  try {
    data = await amapFetch('/v3/place/text', {
      keywords: keyword,
      offset: '8',
      page: '1',
      extensions: 'base',
    });
  } catch {
    return bad('geocode_upstream_error');
  }
  if (data?.status !== '1') return ok({ items: [] });

  const items = (data.pois ?? [])
    .map((p: any) => {
      const [lngS, latS] = String(p.location ?? '').split(',');
      const lng = Number(lngS);
      const lat = Number(latS);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
      return {
        name: String(p.name ?? ''),
        address: String(p.address ?? ''),
        province: normProvince(String(p.pname ?? '')),
        lat,
        lng,
      };
    })
    .filter(Boolean);
  return ok({ items });
}

/** GET /admin/geocode/reverse?lat=..&lng=.. */
export async function reverseGeocode(req: Req) {
  if (!amapConfigured()) return bad('geocode_not_configured');
  const lat = Number(req.query.lat);
  const lng = Number(req.query.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return bad('invalid_coords');

  let data: any;
  try {
    data = await amapFetch('/v3/geocode/regeo', {
      location: `${lng},${lat}`,
      extensions: 'base',
    });
  } catch {
    return bad('geocode_upstream_error');
  }
  if (data?.status !== '1' || !data.regeocode) return bad('geocode_no_match');

  const c = data.regeocode.addressComponent ?? {};
  const province = normProvince(String(c.province ?? ''));
  const city = Array.isArray(c.city) ? c.city[0] : c.city;
  const district = Array.isArray(c.district) ? c.district[0] : c.district;
  const name = [city, district].find((s) => typeof s === 'string' && s.length > 0) ?? province;
  return ok({ province, name: String(name ?? province) });
}
