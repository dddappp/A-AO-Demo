import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      // 开发环境代理API请求到后端
      '/api': {
        target: 'http://localhost:8081',
        changeOrigin: true,
        secure: false,
      },
      '/oauth2': {
        target: 'http://localhost:8081',
        changeOrigin: true,
        secure: false,
      }
    }
  },
  build: {
    outDir: '../src/main/resources/static', // 构建到Spring Boot静态资源目录
    emptyOutDir: true,
    sourcemap: false, // 生产环境不需要sourcemap
    rollupOptions: {
      output: {
        manualChunks: undefined, // 简化chunk分割
      }
    }
  },
  // 生产环境API路径配置
  define: {
    'import.meta.env.VITE_API_BASE_URL': JSON.stringify(''), // 使用相对路径，指向同一域的API
  }
})
