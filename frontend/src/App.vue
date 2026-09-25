<script setup lang="ts">
import { computed, ref } from 'vue'
import CategoryBreakdown from './components/CategoryBreakdown.vue'
import MonthNav from './components/MonthNav.vue'
import SummaryPanel from './components/SummaryPanel.vue'
import { getDummySummary } from './data/dummySummaries'
import { currentMonth, shiftMonth } from './utils/format'

// フェーズ4: API には繋がず、ダミーデータで組む（docs/plan.md）。
// 状態管理ライブラリは入れず、ref / computed で持つ（docs/tech-stack.md）
const month = ref(currentMonth())
const summary = computed(() => getDummySummary(month.value))
</script>

<template>
  <div class="app">
    <div class="header">
      <h1>家計簿</h1>
    </div>

    <MonthNav
      :month="month"
      @prev="month = shiftMonth(month, -1)"
      @next="month = shiftMonth(month, 1)"
    />
    <!-- 予算設定モーダル（S-04）は別の Issue で作る。ボタンは表示のみ -->
    <SummaryPanel :summary="summary" />
    <CategoryBreakdown :categories="summary.categories" />
  </div>
</template>
