import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { ConfigProvider } from 'antd';
import zhCN from 'antd/locale/zh_CN';
import { HashRouter } from 'react-router-dom';
import './index.css';
import App from './App.tsx';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    {/* 跟 App 端主题色对齐（frontend/lib/theme.dart 的 T.accent，蓝绿松石色），
        不用 antd 默认蓝——管理端和 App 是同一个产品，配色也该是一套 */}
    <ConfigProvider locale={zhCN} theme={{ token: { colorPrimary: '#3EA983' } }}>
      <HashRouter>
        <App />
      </HashRouter>
    </ConfigProvider>
  </StrictMode>,
);
