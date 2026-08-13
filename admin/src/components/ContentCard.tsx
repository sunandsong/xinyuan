import type { CSSProperties, ReactNode } from 'react';
import { CARD, CARD_STYLE } from '../theme';

export default function ContentCard({
  children,
  style,
  padding = 0,
  className,
}: {
  children: ReactNode;
  style?: CSSProperties;
  padding?: number | string;
  className?: string;
}) {
  return (
    <div
      className={className}
      style={{
        ...CARD_STYLE,
        background: CARD,
        padding,
        overflow: 'hidden',
        ...style,
      }}
    >
      {children}
    </div>
  );
}
