import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5173,
    proxy: {
      // 開発時は /api を Rails に転送し、CORS を発生させない。
      // 本番は S3 と EC2 でオリジンが分かれるため、そちらは rack-cors で許可する
      // （docs/tech-stack.md の開発環境の前提）。
      // 転送先は API_PROXY_TARGET で変えられる（別の DB で動かした Rails に繋いで確かめるときなど）
      '/api': {
        target: process.env.API_PROXY_TARGET ?? 'http://localhost:3000',
        changeOrigin: true,
      },
    },
  },
})
