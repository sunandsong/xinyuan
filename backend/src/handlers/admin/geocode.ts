import { TMAP_KEY } from '../../config';
import { tmapConfigured, tmapFetch, normProvince } from '../../tmap';
import { bad, ok, Req } from '../../http';

/** GET /admin/map-config —— 管理端加载腾讯地图 JS API GL 用 */
export async function mapConfig(_req: Req) {
  if (!tmapConfigured()) return ok({ available: false });
  return ok({ available: true, key: TMAP_KEY });
}

/** GET /admin/geocode/search?keyword=故宫 */
export async function placeSearch(req: Req) {
  if (!tmapConfigured()) return bad('geocode_not_configured');
  const keyword = String(req.query.keyword ?? '').trim();
  if (!keyword) return bad('invalid_keyword');

  let data: any;
  try {
    data = await tmapFetch('/ws/place/v1/search', {
      keyword,
      boundary: 'region(全国,1)',
      page_size: '8',
      page_index: '1',
    });
  } catch {
    return bad('geocode_upstream_error');
  }
  // 不能把非 0 状态码一律当成「没搜到」——额度超限(121)、key 无效这些是真错误，
  // 吞成空数组的话界面上只显示「无结果」，完全看不出实际原因（踩过一次）
  if (data?.status !== 0) {
    return ok({ items: [], error: String(data?.message ?? '搜索服务异常') });
  }

  const items = (data.data ?? [])
    .map((p: any) => {
      const lat = Number(p.location?.lat);
      const lng = Number(p.location?.lng);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
      return {
        name: String(p.title ?? ''),
        address: String(p.address ?? ''),
        province: normProvince(String(p.ad_info?.province ?? '')),
        lat,
        lng,
      };
    })
    .filter(Boolean);
  return ok({ items });
}

/** GET /admin/geocode/reverse?lat=..&lng=.. */
export async function reverseGeocode(req: Req) {
  if (!tmapConfigured()) return bad('geocode_not_configured');
  const lat = Number(req.query.lat);
  const lng = Number(req.query.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return bad('invalid_coords');

  let data: any;
  try {
    data = await tmapFetch('/ws/geocoder/v1/', {
      location: `${lat},${lng}`,
    });
  } catch {
    return bad('geocode_upstream_error');
  }
  if (data?.status !== 0 || !data.result) return bad('geocode_no_match');

  const c = data.result.address_component ?? {};
  const province = normProvince(String(c.province ?? ''));
  const name = [c.city, c.district].find((s: unknown) => typeof s === 'string' && s.length > 0) ?? province;
  return ok({ province, name: String(name ?? province) });
}
