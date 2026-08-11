export default function Placeholder({ title }: { title: string }) {
  return (
    <div style={{ padding: 48, textAlign: 'center', color: '#999' }}>
      <h2 style={{ color: '#333' }}>{title}</h2>
      <p>建设中</p>
    </div>
  );
}
