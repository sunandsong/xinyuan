import { Component, type ErrorInfo, type ReactNode } from 'react';

export default class ErrorBoundary extends Component<
  { children: ReactNode },
  { error: Error | null }
> {
  state = { error: null as Error | null };

  static getDerivedStateFromError(error: Error) {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('[admin] render error', error, info);
  }

  render() {
    if (this.state.error) {
      return (
        <div style={{ padding: 40, fontFamily: 'system-ui, sans-serif', color: '#1C1C21' }}>
          <h2 style={{ marginTop: 0 }}>页面渲染出错</h2>
          <p style={{ color: '#8A8C98' }}>{this.state.error.message}</p>
          <button
            type="button"
            onClick={() => window.location.reload()}
            style={{
              marginTop: 12,
              padding: '8px 16px',
              borderRadius: 8,
              border: 'none',
              background: '#3EA983',
              color: '#fff',
              cursor: 'pointer',
            }}
          >
            刷新页面
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}
