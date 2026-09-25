<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import CategoryBreakdown from './components/CategoryBreakdown.vue'
import EntryListHead from './components/EntryListHead.vue'
import EntryTable from './components/EntryTable.vue'
import MonthNav from './components/MonthNav.vue'
import SearchBar from './components/SearchBar.vue'
import SummaryPanel from './components/SummaryPanel.vue'
import { dummyCategories, fetchDummyEntries, getDummySummary } from './data/dummyData'
import type { Entry, SearchConditions } from './types'
import { countLabel, emptyConditions, emptyMessage, periodNote } from './utils/entryList'
import { currentMonth, shiftMonth } from './utils/format'

// フェーズ4: API には繋がず、ダミーデータで組む（docs/plan.md）。
// 状態管理ライブラリは入れず、ref / computed で持つ（docs/tech-stack.md）
const month = ref(currentMonth())

// 反映済みの検索条件。「検索」を押すまで変わらず、月を切り替えても保持される（docs/screens.md「検索条件の扱い」）
const applied = ref<SearchConditions>(emptyConditions())

// サマリーと内訳は対象月全体の値で、検索条件の影響を受けない（F-08）
const summary = computed(() => getDummySummary(month.value))

const entries = ref<Entry[]>([])
const loading = ref(false)

// 月か検索条件が変わるたびに明細を取り直す。古い応答が新しい応答を上書きしないよう、最後の要求だけを採用する
let latestRequest = 0
watch(
  [month, applied],
  async () => {
    const request = ++latestRequest
    loading.value = true
    const result = await fetchDummyEntries(month.value, applied.value)
    if (request !== latestRequest) return
    entries.value = result
    loading.value = false
  },
  { immediate: true },
)

const count = computed(() =>
  loading.value
    ? ''
    : countLabel(applied.value, month.value, summary.value.entry_count, entries.value.length),
)
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
    <SummaryPanel :summary="summary" :period-note="periodNote(applied, month)" />
    <CategoryBreakdown :categories="summary.categories" />

    <SearchBar
      :categories="dummyCategories"
      @search="applied = $event"
      @clear="applied = emptyConditions()"
    />

    <!-- 追加・選択・編集・削除は別の Issue（モーダルと選択モード）で動かす。ボタンは表示のみ -->
    <EntryListHead :count-label="count" />
    <EntryTable :entries="entries" :loading="loading" :empty-message="emptyMessage(applied)" />
  </div>
</template>
