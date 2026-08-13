import { useEffect, useState, type CSSProperties, type ReactNode } from 'react';
import { Image } from 'antd';
import { freshPhotoUrl } from '../photoUrls';

/** 云存储稳定链接 → 临时签名后再显示（跟 AvatarCell 同理） */
export default function CloudImage({
  url,
  width,
  height,
  style,
  fallback = <span style={{ color: '#ccc' }}>无图</span>,
}: {
  url?: string | null;
  width?: number;
  height?: number;
  style?: CSSProperties;
  fallback?: ReactNode;
}) {
  const [src, setSrc] = useState<string | null>(null);
  const [broken, setBroken] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    setBroken(false);
    if (!url) {
      setSrc(null);
      setLoading(false);
      return;
    }
    let cancelled = false;
    setLoading(true);
    setSrc(null);
    freshPhotoUrl(url)
      .then((u) => {
        if (!cancelled) {
          setSrc(u);
          if (!u) setBroken(true);
        }
      })
      .catch(() => {
        if (!cancelled) setBroken(true);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [url]);

  if (!url || broken) return <>{fallback}</>;
  if (loading || !src) {
    return (
      <span
        style={{
          display: 'inline-block',
          width: width ?? 64,
          height: height ?? 64,
          background: '#f5f5f5',
          borderRadius: 6,
          ...style,
        }}
      />
    );
  }

  return (
    <Image
      src={src}
      width={width}
      height={height}
      style={style}
      referrerPolicy="no-referrer"
      preview={{ src }}
      onError={() => setBroken(true)}
    />
  );
}
