import { useState } from 'react';
import { Button, Card, Input, Typography } from 'antd';
import { API_BASE, setKey } from './api';

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
        background: '#f0f2f5',
      }}
    >
      <Card style={{ width: 360 }}>
        <div style={{ textAlign: 'center', fontSize: 40 }}>🔑</div>
        <Typography.Title level={4} style={{ textAlign: 'center', marginTop: 8 }}>
          人生清单 · 管理端
        </Typography.Title>
        <Input.Password
          placeholder="请输入管理密钥"
          value={value}
          onChange={(e) => setValue(e.target.value)}
          onPressEnter={handleEnter}
          style={{ marginTop: 16 }}
        />
        {error && (
          <Typography.Text type="danger" style={{ display: 'block', marginTop: 8 }}>
            {error}
          </Typography.Text>
        )}
        <Button type="primary" block loading={loading} onClick={handleEnter} style={{ marginTop: 16 }}>
          进入
        </Button>
      </Card>
    </div>
  );
}
