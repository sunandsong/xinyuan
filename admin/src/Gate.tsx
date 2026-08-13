import { useState } from 'react';
import { Button, Input, Typography } from 'antd';
import { API_BASE, setKey } from './api';
import { ACCENT, CARD_STYLE, GRADIENT, INK, MUTED } from './theme';

export default function Gate() {
  const [value, setValue] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  async function handleEnter() {
    const key = value.trim();
    if (!key) return;
    setLoading(true);
    setError('');
    try {
      const res = await fetch(`${API_BASE}/admin/ping`, { headers: { 'X-Admin-Key': key } });
      if (res.status === 403) {
        const data = await res.json().catch(() => ({}));
        setError(data.error === 'admin_disabled' ? '服务端未配置管理密钥' : '验证失败');
        return;
      }
      if (!res.ok) {
        setError('密钥错误');
        return;
      }
      setKey(key);
    } catch {
      setError('网络错误，请重试');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: GRADIENT,
        padding: 24,
      }}
    >
      <div
        style={{
          width: '100%',
          maxWidth: 400,
          ...CARD_STYLE,
          background: '#fff',
          padding: '36px 32px 32px',
        }}
      >
        <div style={{ textAlign: 'center', marginBottom: 24 }}>
          <img src="/logo.png" alt="" style={{ width: 48, height: 48, marginBottom: 12 }} />
          <Typography.Title level={3} style={{ margin: 0, color: INK }}>
            人生清单
          </Typography.Title>
          <div style={{ color: MUTED, fontSize: 14, marginTop: 6 }}>管理后台</div>
        </div>
        <div className="admin-form-field" style={{ marginBottom: 20 }}>
          <div className="admin-form-field__label">管理密钥</div>
          <Input.Password
            placeholder="请输入管理密钥"
            value={value}
            onChange={(e) => setValue(e.target.value)}
            onPressEnter={handleEnter}
            size="large"
          />
        </div>
        {error && (
          <Typography.Text type="danger" style={{ display: 'block', marginTop: 10, fontSize: 13 }}>
            {error}
          </Typography.Text>
        )}
        <Button
          type="primary"
          block
          size="large"
          loading={loading}
          onClick={handleEnter}
          style={{ marginTop: 16, background: ACCENT }}
        >
          进入管理端
        </Button>
      </div>
    </div>
  );
}
