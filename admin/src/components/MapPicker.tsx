import { useCallback, useEffect, useRef, useState } from 'react';
import { Alert, AutoComplete, Button, InputNumber, Space, Typography, message } from 'antd';
import { AimOutlined, EnvironmentOutlined } from '@ant-design/icons';
import { api } from '../api';

/** 腾讯地图 JS API GL 没有官方 npm 加载器，官方推荐做法就是动态插入 script
 * 标签 + callback，等 window.TMap 就绪。同一个 key 全局只挂一次脚本。 */
let tmapLoading: Promise<any> | null = null;
function loadTMap(key: string): Promise<any> {
  if ((window as any).TMap) return Promise.resolve((window as any).TMap);
  if (tmapLoading) return tmapLoading;
  tmapLoading = new Promise((resolve, reject) => {
    const cbName = `__tmapCb${Date.now()}`;
    (window as any)[cbName] = () => {
      delete (window as any)[cbName];
      resolve((window as any).TMap);
    };
    const script = document.createElement('script');
    script.src = `https://map.qq.com/api/gljs?v=1.exp&key=${key}&callback=${cbName}`;
    script.onerror = () => reject(new Error('腾讯地图脚本加载失败'));
    document.head.appendChild(script);
  });
  return tmapLoading;
}

interface PlaceHit {
  name: string;
  address: string;
  province: string;
  lat: number;
  lng: number;
}

const DEFAULT_CENTER = { lat: 39.9042, lng: 116.4074 };

function hasCoords(lat: number, lng: number) {
  return Number.isFinite(lat) && Number.isFinite(lng) && !(lat === 0 && lng === 0);
}

/** 腾讯地图选点：搜索景点、点击地图重新放标记、自动回填省份 */
export default function MapPicker({
  lat,
  lng,
  onChange,
}: {
  lat: number;
  lng: number;
  onChange: (patch: { lat: number; lng: number; province?: string; name?: string }) => void;
}) {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInst = useRef<any>(null);
  const markerRef = useRef<any>(null);
  const tmapRef = useRef<any>(null);
  const onChangeRef = useRef(onChange);
  onChangeRef.current = onChange;

  const [ready, setReady] = useState(false);
  const [mapError, setMapError] = useState<string | null>(null);
  const [searching, setSearching] = useState(false);
  const [searchError, setSearchError] = useState<string | null>(null);
  const [options, setOptions] = useState<Array<{ value: string; label: string; hit: PlaceHit }>>([]);
  const [keyword, setKeyword] = useState('');

  const reverseGeocode = useCallback(async (la: number, ln: number) => {
    try {
      const r = await api.get(`/admin/geocode/reverse?lat=${la}&lng=${ln}`);
      onChangeRef.current({ lat: la, lng: ln, province: r.province, name: r.name });
    } catch {
      onChangeRef.current({ lat: la, lng: ln });
    }
  }, []);

  // MultiMarker 官方文档没有拖拽标记的支持（跟高德 Marker 的 draggable 不一样），
  // 所以选点只靠「点地图重新放标记」+ 下面手填经纬度兜底，不做拖拽调整
  const placeMarker = useCallback(
    (la: number, ln: number, moveMap = true) => {
      const TMap = tmapRef.current;
      const map = mapInst.current;
      if (!TMap || !map) return;
      const position = new TMap.LatLng(la, ln);
      if (!markerRef.current) {
        markerRef.current = new TMap.MultiMarker({
          map,
          geometries: [{ id: 'picked', position }],
        });
      } else {
        markerRef.current.updateGeometries([{ id: 'picked', position }]);
      }
      if (moveMap) map.setCenter(position);
    },
    [],
  );

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const cfg = await api.get('/admin/map-config');
        if (!cfg.available) {
          setMapError('未配置腾讯地图 Key（TMAP_KEY），请手动填写经纬度');
          return;
        }
        const TMap = await loadTMap(cfg.key);
        if (cancelled || !mapRef.current) return;
        tmapRef.current = TMap;
        const center = hasCoords(lat, lng)
          ? new TMap.LatLng(lat, lng)
          : new TMap.LatLng(DEFAULT_CENTER.lat, DEFAULT_CENTER.lng);
        const map = new TMap.Map(mapRef.current, {
          zoom: hasCoords(lat, lng) ? 14 : 5,
          center,
        });
        map.on('click', (e: any) => {
          const la = e.latLng.getLat();
          const ln = e.latLng.getLng();
          placeMarker(la, ln, false);
          reverseGeocode(la, ln);
        });
        mapInst.current = map;
        if (hasCoords(lat, lng)) placeMarker(lat, lng, false);
        setReady(true);
      } catch (e: any) {
        setMapError(e.message ?? '地图加载失败');
      }
    })();
    return () => {
      cancelled = true;
      mapInst.current?.destroy();
      mapInst.current = null;
      markerRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- 只初始化一次
  }, []);

  useEffect(() => {
    if (!ready || !hasCoords(lat, lng)) return;
    placeMarker(lat, lng, false);
  }, [lat, lng, ready, placeMarker]);

  async function onSearch(q: string) {
    setKeyword(q);
    if (!q.trim()) {
      setOptions([]);
      return;
    }
    setSearching(true);
    setSearchError(null);
    try {
      const r = await api.get(`/admin/geocode/search?keyword=${encodeURIComponent(q.trim())}`);
      const items: PlaceHit[] = r.items ?? [];
      // 后端把上游真实错误（额度超限等）透过来了就明说，别让用户以为是「没搜到」
      if (r.error) setSearchError(r.error);
      setOptions(
        items.map((hit) => ({
          value: `${hit.name}@${hit.lng},${hit.lat}`,
          label: `${hit.name}${hit.address ? ` · ${hit.address}` : ''}（${hit.province}）`,
          hit,
        })),
      );
    } catch {
      setOptions([]);
      setSearchError('搜索请求失败');
    } finally {
      setSearching(false);
    }
  }

  function pickPlace(hit: PlaceHit) {
    setKeyword(hit.name);
    placeMarker(hit.lat, hit.lng, true);
    onChange({ lat: hit.lat, lng: hit.lng, province: hit.province, name: hit.name });
  }

  function useMyLocation() {
    if (!navigator.geolocation) {
      message.error('浏览器不支持定位');
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const la = pos.coords.latitude;
        const ln = pos.coords.longitude;
        placeMarker(la, ln, true);
        reverseGeocode(la, ln);
      },
      () => message.error('定位失败，请检查浏览器权限'),
      { enableHighAccuracy: true, timeout: 10000 },
    );
  }

  return (
    <div>
      {mapError ? (
        <Alert type="warning" showIcon message={mapError} style={{ marginBottom: 12 }} />
      ) : (
        <>
          <Space style={{ width: '100%', marginBottom: 8 }} wrap>
            <AutoComplete
              style={{ minWidth: 280, flex: 1 }}
              options={options}
              value={keyword}
              onSearch={onSearch}
              onSelect={(_, opt) => pickPlace((opt as any).hit)}
              placeholder="搜索景点或地址"
              notFoundContent={searching ? '搜索中…' : (searchError ?? '无结果')}
            />
            <Button icon={<AimOutlined />} onClick={useMyLocation}>
              当前位置
            </Button>
          </Space>
          {searchError && (
            <Alert
              type="warning"
              showIcon
              message={searchError}
              style={{ marginBottom: 8 }}
            />
          )}
          <div
            ref={mapRef}
            style={{
              height: 320,
              borderRadius: 8,
              overflow: 'hidden',
              border: '1px solid #E6E7EC',
              background: '#f5f5f5',
            }}
          />
          <Typography.Text type="secondary" style={{ fontSize: 12, display: 'block', marginTop: 8 }}>
            <EnvironmentOutlined /> 点击地图选点（不支持拖动标记，微调用下面的经纬度输入框），省份会自动识别
          </Typography.Text>
        </>
      )}
      <Space style={{ marginTop: 12 }} wrap>
        <span style={{ color: '#8A8C98', fontSize: 13 }}>纬度</span>
        <InputNumber
          style={{ width: 140 }}
          value={lat}
          step={0.0001}
          onChange={(n) => onChange({ lat: n ?? 0, lng })}
        />
        <span style={{ color: '#8A8C98', fontSize: 13 }}>经度</span>
        <InputNumber
          style={{ width: 140 }}
          value={lng}
          step={0.0001}
          onChange={(n) => onChange({ lat, lng: n ?? 0 })}
        />
      </Space>
    </div>
  );
}
