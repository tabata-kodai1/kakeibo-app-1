<script setup lang="ts">
import { formatMonthLabel } from '../utils/format'

// 対象月の表示と、前月・翌月への切り替え（F-04）。月の状態は親が持つ
defineProps<{ month: string }>()
const emit = defineEmits<{ prev: []; next: [] }>()
</script>

<template>
  <div class="month-nav">
    <button type="button" @click="emit('prev')">◀ 前月</button>
    <span class="current" aria-live="polite">{{ formatMonthLabel(month) }}</span>
    <button type="button" @click="emit('next')">翌月 ▶</button>
  </div>
</template>
