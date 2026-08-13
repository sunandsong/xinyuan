import { useCallback, useEffect, useRef, useState } from 'react';
import { Alert, AutoComplete, Button, InputNumber, Space, Typography, message } from 'antd';
import { AimOutlined, EnvironmentOutlined } from '@ant-design/icons';
import AMapLoader from '@amap/amap-jsapi-loader';
import { api } from '../api';

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

/** 高德地图选点：搜索景点、点击/拖动标记、自动回填省份 */
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
  const amapRef = useRef<any>(null);
  const onChangeRef = useRef(onChange);
  onChangeRef.current = onChange;

  const [ready, setReady] = useState(false);
  const [mapError, setMapError] = useState<string | null>(null);
  const [searching, setSearching] = useState(false);
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

  const placeMarker = useCallback(
    (la: number, ln: number, moveMap = true) => {
      const AMap = amapRef.current;
      const map = mapInst.current;
      if (!AMap || !map) return;
      if (!markerRef.current) {
        markerRef.current = new AMap.Marker({
          position: [ln, la],
          draggable: true,
        });
        markerRef.current.on('dragend', (e: any) => {
          const pos = e.target.getPosition();
          reverseGeocode(pos.getLat(), pos.getLng());
        });
        map.add(markerRef.current);
      } else {
        markerRef.current.setPosition([ln, la]);
      }
      if (moveMap) map.setZoomAndCenter(14, [ln, la]);
    },
    [reverseGeocode],
  );

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const cfg = await api.get('/admin/map-config');
        if (!cfg.available) {
          setMapError('未配置高德地图 Key（AMAP_KEY），请手动填写经纬度');
          return;
        }
        if (cfg.securityCode) {
          (window as any)._AMapSecurityConfig = { securityJsCode: cfg.securityCode };
        }
        const AMap = await AMapLoader.load({
          key: cfg.key,
          version: '2.0',
          plugins: [],
        });
        if (cancelled || !mapRef.current) return;
        amapRef.current = AMap;
        const center = hasCoords(lat, lng) ? [lng, lat] : [DEFAULT_CENTER.lng, DEFAULT_CENTER.lat];
        const map = new AMap.Map(mapRef.current, {
          zoom: hasCoords(lat, lng) ? 14 : 5,
          center,
          viewMode: '2D',
        });
        map.on('click', (e: any) => {
          const la = e.lnglat.getLat();
          const ln = e.lnglat.getLng();
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
    try {
      const r = await api.get(`/admin/geocode/search?keyword=${encodeURIComponent(q.trim())}`);
      const items: PlaceHit[] = r.items ?? [];
      setOptions(
        items.map((hit) => ({
          value: `${hit.name}@${hit.lng},${hit.lat}`,
          label: `${hit.name}${hit.address ? ` · ${hit.address}` : ''}（${hit.province}）`,
          hit,
        })),
      );
    } catch {
      setOptions([]);
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
              notFoundContent={searching ? '搜索中…' : '无结果'}
            />
            <Button icon={<AimOutlined />} onClick={useMyLocation}>
              当前位置
            </Button>
          </Space>
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
            <EnvironmentOutlined /> 点击地图或拖动标记选点，省份会自动识别
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
