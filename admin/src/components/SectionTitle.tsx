import type { ReactNode } from 'react';
import { ACCENT, INK } from '../theme';

export default function SectionTitle({ children }: { children: ReactNode }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, margin: '28px 0 12px' }}>
      <span style={{ width: 3, height: 14, borderRadius: 2, background: ACCENT }} />
      <span style={{ fontSize: 14, fontWeight: 600, color: INK }}>{children}</span>
    </div>
  );
}
