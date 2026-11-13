/// <reference types="vitest/config" />
import { fileURLToPath, URL } from 'node:url'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react()],
  resolve: { alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) } },
  // Loaded with import() when a video is made: listed so the dev server bundles them at start instead of discovering them
  // mid-session, which reloads the page under a running test.
  optimizeDeps: { include: ['mp4-muxer', 'webm-muxer', 'gifenc'] },
  server: {
    port: 5173,
    proxy: {
      '/api': { target: 'http://localhost:4000', changeOrigin: true },
      '/uploads': { target: 'http://localhost:4000', changeOrigin: true },
    },
  },
  build: {
    rollupOptions: {
      // The presenter view is a separate browser entry.
      input: {
        main: fileURLToPath(new URL('./index.html', import.meta.url)),
        'presenter-view': fileURLToPath(new URL('./presenter-view.html', import.meta.url)),
      },
      output: {
        manualChunks: (id) => (id.includes('/node_modules/fabric/') ? 'fabric' : undefined),
      },
    },
  },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
    css: false,
    exclude: ['node_modules/**'],
  },
})
