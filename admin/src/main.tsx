import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { ConfigProvider } from 'antd';
import zhCN from 'antd/locale/zh_CN';
import { HashRouter } from 'react-router-dom';
import './index.css';
import App from './App.tsx';
import ErrorBoundary from './components/ErrorBoundary.tsx';
import { antdTheme } from './theme';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ErrorBoundary>
      <ConfigProvider locale={zhCN} theme={antdTheme}>
        <HashRouter>
          <App />
        </HashRouter>
      </ConfigProvider>
    </ErrorBoundary>
  </StrictMode>,
);
