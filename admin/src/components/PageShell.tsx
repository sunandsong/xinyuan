import type { ReactNode } from 'react';
import { Breadcrumb } from 'antd';
import { INK, MUTED } from '../theme';

export default function PageShell({
  title,
  parent,
  subtitle,
  extra,
  children,
}: {
  title: string;
  parent?: string;
  subtitle?: string;
  extra?: ReactNode;
  children: ReactNode;
}) {
  const today = new Date();
  const dateStr = `${today.getFullYear()}年${today.getMonth() + 1}月${today.getDate()}日`;

  return (
    <div style={{ padding: '20px 24px 32px' }}>
      {parent && (
        <Breadcrumb
          style={{ marginBottom: 8 }}
          items={[{ title: parent }, { title }]}
        />
      )}
      <div
        style={{
          display: 'flex',
          alignItems: 'flex-end',
          justifyContent: 'space-between',
          marginBottom: 20,
          gap: 16,
          flexWrap: 'wrap',
        }}
      >
        <div>
          {!parent && (
            <div style={{ color: MUTED, fontSize: 13, marginBottom: 4 }}>{dateStr}</div>
          )}
          <div style={{ fontSize: 22, fontWeight: 700, color: INK, lineHeight: 1.3 }}>{title}</div>
          {subtitle && (
            <div style={{ color: MUTED, fontSize: 13, marginTop: 4 }}>{subtitle}</div>
          )}
        </div>
        {extra}
      </div>
      {children}
    </div>
  );
}
