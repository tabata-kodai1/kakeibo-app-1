<script setup lang="ts">
// 明細一覧の見出し。件数表示と「＋ 追加」「選択」ボタン（動作するのは別の Issue）
defineProps<{ countLabel: string }>()
const emit = defineEmits<{ add: []; select: [] }>()
</script>

<template>
  <div class="list-head">
    <span class="count">{{ countLabel }}</span>
    <span class="actions">
      <button type="button" class="btn btn-primary btn-sm" @click="emit('add')">＋ 追加</button>
      <button type="button" class="btn btn-sm" @click="emit('select')">選択</button>
    </span>
  </div>
</template>
