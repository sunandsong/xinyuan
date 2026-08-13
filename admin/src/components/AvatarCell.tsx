import { useEffect, useState } from 'react';
import { freshPhotoUrl } from '../photoUrls';

const AVATAR_COLORS = ['#5B8DEF', '#E0A64B', '#E0708A', '#4FB88A', '#A080E0'];

/** 头像：云存储稳定链接先换临时签名再显示，失败回退昵称首字彩圆 */
export default function AvatarCell({ url, name }: { url?: string | null; name?: string }) {
  const [src, setSrc] = useState<string | null>(null);
  const [broken, setBroken] = useState(false);
  const n = name || '?';
  const color = AVATAR_COLORS[Math.abs([...n].reduce((h, c) => h * 31 + c.charCodeAt(0), 0)) % AVATAR_COLORS.length];

  useEffect(() => {
    setBroken(false);
    if (!url) {
      setSrc(null);
      return;
    }
    let cancelled = false;
    freshPhotoUrl(url)
      .then((u) => {
        if (!cancelled) setSrc(u);
      })
      .catch(() => {
        if (!cancelled) setBroken(true);
      });
    return () => {
      cancelled = true;
    };
  }, [url]);

  if (src && !broken) {
    return (
      <img
        src={src}
        alt=""
        referrerPolicy="no-referrer"
        onError={() => setBroken(true)}
        style={{ width: 32, height: 32, borderRadius: '50%', objectFit: 'cover', flexShrink: 0 }}
      />
    );
  }
  return (
    <div
      style={{
        width: 32,
        height: 32,
        borderRadius: '50%',
        background: color,
        color: '#fff',
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontWeight: 600,
        flexShrink: 0,
      }}
    >
      {n.slice(0, 1)}
    </div>
  );
}
