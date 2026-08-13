import type { ReactNode } from 'react';
import { MUTED } from '../theme';

export default function EmptyState({
  children,
  height = 200,
}: {
  children: ReactNode;
  height?: number;
}) {
  return (
    <div
      style={{
        height,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        color: MUTED,
        fontSize: 14,
        gap: 8,
      }}
    >
      {children}
    </div>
  );
}
