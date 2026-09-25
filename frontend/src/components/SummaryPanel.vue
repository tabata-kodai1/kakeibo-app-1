<script setup lang="ts">
import { computed } from 'vue'
import type { Summary } from '../types'
import { formatAmount } from '../utils/format'

// 月次サマリー（F-01）。画面の主役は「残額」（docs/screens.md S-01）
const props = defineProps<{ summary: Summary; periodNote?: string | null }>()
const emit = defineEmits<{ 'open-budget': [] }>()

const budgetSet = computed(() => props.summary.budget !== null)
const over = computed(() => props.summary.over_budget)

// 進捗バーの表示規則（docs/features.md F-01）。usage_rate が null になるのは予算 0 円のとき
//   予算 0・支出 0   → 0%
//   予算 0・支出あり → 100% の警告色（予算 0 に対する支出はすべて超過）
//   予算 1 以上      → usage_rate。100 を超えるときはバーを 100% で止める
const barPercent = computed(() => {
  const { usage_rate, expense_total } = props.summary
  if (usage_rate === null) return expense_total > 0 ? 100 : 0
  return Math.min(usage_rate, 100)
})

const barLabel = computed(() => {
  const { usage_rate, expense_total } = props.summary
  if (usage_rate !== null) return `${usage_rate}% 使用`
  return expense_total > 0 ? '予算 0 円を超過' : '0% 使用'
})
</script>

<template>
  <div class="card summary">
    <div class="summary-head">
      <div class="item">
        <div class="label">予算</div>
        <div class="value">{{ budgetSet ? formatAmount(summary.budget!) : '未設定' }}</div>
      </div>
      <div class="item">
        <div class="label">使用</div>
        <div class="value">{{ formatAmount(summary.expense_total) }}</div>
      </div>
      <div class="spacer"></div>
      <button type="button" class="btn btn-sm" @click="emit('open-budget')">予算を設定</button>
    </div>

    <template v-if="budgetSet">
      <div
        class="progress"
        :class="{ over }"
        role="progressbar"
        aria-label="予算の使用率"
        aria-valuemin="0"
        aria-valuemax="100"
        :aria-valuenow="barPercent"
      >
        <div class="fill" :style="{ width: `${barPercent}%` }"></div>
      </div>
      <div class="progress-label">{{ barLabel }}</div>
    </template>

    <div class="remaining" :class="{ over }">
      <template v-if="summary.remaining === null">
        <div class="label">残り</div>
        <div class="value">―</div>
        <div class="note">予算が未設定です</div>
      </template>
      <template v-else-if="over">
        <div class="label">超過</div>
        <div class="value">{{ formatAmount(summary.remaining) }}<span class="unit">円</span></div>
      </template>
      <template v-else>
        <div class="label">残り</div>
        <div class="value">{{ formatAmount(summary.remaining) }}<span class="unit">円</span></div>
      </template>
      <!-- 明細が対象月の外を含む期間検索中のみ。サマリーが指す期間を示す（F-08） -->
      <div v-if="periodNote" class="note">{{ periodNote }}</div>
    </div>
  </div>
</template>
