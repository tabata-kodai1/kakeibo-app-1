<script setup lang="ts">
// エラーバナー（docs/screens.md「エラーの表示」）。通信失敗時に画面上部へ出し、閉じられる。
// 次の操作（月切替・検索・保存など）を始めた時点で消えるのは、親が message を null に戻すことで行う
defineProps<{ message: string }>()
const emit = defineEmits<{ close: [] }>()
</script>

<template>
  <div class="error-banner" role="alert">
    <span>{{ message }}</span>
    <button
      type="button"
      class="btn-icon"
      title="閉じる"
      aria-label="閉じる"
      @click="emit('close')"
    >
      ×
    </button>
  </div>
</template>
