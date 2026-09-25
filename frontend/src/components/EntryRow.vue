<script setup lang="ts">
import type { Entry } from '../types'
import { formatShortDate, formatSignedAmount } from '../utils/format'

// 明細 1 行（F-04）。編集・削除ボタンは通常モードのみ。選択モードの列は別の Issue で足す
defineProps<{ entry: Entry }>()
const emit = defineEmits<{ edit: [entry: Entry]; delete: [entry: Entry] }>()
</script>

<template>
  <tr>
    <td>{{ formatShortDate(entry.entry_date) }}</td>
    <td>{{ entry.category_name }}</td>
    <td class="col-amount">
      <span class="amount" :class="entry.category_type === 'INCOME' ? 'income' : 'expense'">
        {{ formatSignedAmount(entry.amount, entry.category_type) }}
      </span>
    </td>
    <!-- 長いメモは省略表示し、全文は title で見られる -->
    <td class="memo" :title="entry.memo ?? undefined">{{ entry.memo }}</td>
    <td class="col-actions">
      <button
        type="button"
        class="btn-icon"
        title="編集"
        aria-label="編集"
        @click="emit('edit', entry)"
      >
        ✎
      </button>
      <button
        type="button"
        class="btn-icon"
        title="削除"
        aria-label="削除"
        @click="emit('delete', entry)"
      >
        🗑
      </button>
    </td>
  </tr>
</template>
