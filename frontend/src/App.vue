<script setup lang="ts">
import { onMounted, ref } from 'vue'

// 画面の実装はフェーズ4から。ここでは proxy 経由で Rails に届くことだけを確かめる。
const health = ref('確認中…')

onMounted(async () => {
  try {
    const res = await fetch('/api/health')
    health.value = `${res.status} ${await res.text()}`
  } catch (e) {
    health.value = `失敗: ${String(e)}`
  }
})
</script>

<template>
  <main>
    <h1>kakeibo-app-1</h1>
    <p>GET /api/health → {{ health }}</p>
  </main>
</template>
