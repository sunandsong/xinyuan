/** App 同款清单图标：渐变底 + 白色勾选，侧栏/登录页通用 */
export default function BrandLogo({ size = 36 }: { size?: number }) {
  const icon = Math.round(size * 0.56);
  return (
    <div
      aria-hidden
      style={{
        width: size,
        height: size,
        borderRadius: Math.round(size * 0.28),
        background: 'linear-gradient(135deg, #4B84DB 0%, #5EB87C 100%)',
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
        boxShadow: '0 2px 8px rgba(62, 169, 131, 0.22)',
      }}
    >
      <svg width={icon} height={icon} viewBox="0 0 24 24" fill="none">
        <path
          d="M4.5 7.5 7 10l3.5-4"
          stroke="#fff"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <path d="M12 8.5h8" stroke="#fff" strokeWidth="2" strokeLinecap="round" />
        <path
          d="M4.5 15.5 7 18l3.5-4"
          stroke="#fff"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <path d="M12 16.5h8" stroke="#fff" strokeWidth="2" strokeLinecap="round" />
      </svg>
    </div>
  );
}
