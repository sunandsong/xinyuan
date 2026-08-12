import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  // 本地开发走代理保持同源：后端 CORS 只放行静态托管域名，localhost 直连会被浏览器拦
  server: {
    proxy: {
      '/api': {
        target: 'https://renshengqingdan-d8feva5q55d12bab-1258070735.ap-shanghai.app.tcloudbase.com',
        changeOrigin: true,
      },
    },
  },
})
