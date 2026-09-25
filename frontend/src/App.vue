<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import BudgetModal from './components/BudgetModal.vue'
import BulkActionBar from './components/BulkActionBar.vue'
import CategoryBreakdown from './components/CategoryBreakdown.vue'
import ConfirmDialog from './components/ConfirmDialog.vue'
import EntryFormModal from './components/EntryFormModal.vue'
import EntryListHead from './components/EntryListHead.vue'
import EntryTable from './components/EntryTable.vue'
import MonthNav from './components/MonthNav.vue'
import SearchBar from './components/SearchBar.vue'
import SummaryPanel from './components/SummaryPanel.vue'
import { dummyCategories, fetchDummyEntries, getDummySummary } from './data/dummyData'
import type { Entry, SearchConditions } from './types'
import { countLabel, emptyConditions, emptyMessage, periodNote } from './utils/entryList'
import { currentMonth, defaultEntryDate, shiftMonth } from './utils/format'

// フェーズ4: API には繋がず、ダミーデータで組む（docs/plan.md）。
// 状態管理ライブラリは入れず、ref / computed で持つ（docs/tech-stack.md）。
// モーダルの「保存」「削除する」と一括操作の「適用」は、検証と画面の遷移までを行い、データは更新しない。
// フェーズ5 で API（POST / PUT / DELETE / PATCH）に繋ぎ、そのあとサマリーと一覧を取り直す。
const month = ref(currentMonth())

// 反映済みの検索条件。「検索」を押すまで変わらず、月を切り替えても保持される（docs/screens.md「検索条件の扱い」）
const applied = ref<SearchConditions>(emptyConditions())

// サマリーと内訳は対象月全体の値で、検索条件の影響を受けない（F-08）
const summary = computed(() => getDummySummary(month.value))

const entries = ref<Entry[]>([])
const loading = ref(false)

// --- 選択モード（F-09）
const selectMode = ref(false)
const selectedIds = ref<ReadonlySet<number>>(new Set())

const selectedCount = computed(() => selectedIds.value.size)
// 選択行の収支区分。0 件なら null、支出と収入が混在していれば 'MIXED'
const selectedType = computed(() => {
  const types = new Set(
    entries.value.filter((e) => selectedIds.value.has(e.id)).map((e) => e.category_type),
  )
  if (types.size === 0) return null
  return types.size > 1 ? 'MIXED' : [...types][0]
})

function toggleRow(id: number) {
  const next = new Set(selectedIds.value)
  if (!next.delete(id)) next.add(id)
  selectedIds.value = next
}

function toggleAll(checked: boolean) {
  selectedIds.value = checked ? new Set(entries.value.map((e) => e.id)) : new Set()
}

function clearSelection() {
  selectedIds.value = new Set()
}

function finishSelectMode() {
  selectMode.value = false
  clearSelection()
}

// 月か検索条件が変わるたびに明細を取り直す。古い応答が新しい応答を上書きしないよう、最後の要求だけを採用する。
// 一覧が変わるので、選択もすべて解除する（選択モード自体は維持する。docs/screens.md「選択モードの扱い」）
let latestRequest = 0
watch(
  [month, applied],
  async () => {
    const request = ++latestRequest
    loading.value = true
    clearSelection()
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

// --- 収支入力モーダル（S-02）。編集中の明細は、閉じるときの表示崩れを避けるため開閉とは別に持つ
const entryModalOpen = ref(false)
const editingEntry = ref<Entry | null>(null)

function openAddModal() {
  editingEntry.value = null
  entryModalOpen.value = true
}

function openEditModal(entry: Entry) {
  editingEntry.value = entry
  entryModalOpen.value = true
}

// --- 予算設定モーダル（S-04）
const budgetModalOpen = ref(false)

// --- 削除確認ダイアログ（S-03）。単体は行の削除ボタン、一括は一括操作バーの「削除」から開く
const deleteOpen = ref(false)
const deleteBulk = ref(false)
const deleteMessage = computed(() =>
  deleteBulk.value ? `${selectedCount.value}件のデータを削除します。` : 'このデータを削除します。',
)

function openDeleteDialog(bulk: boolean) {
  deleteBulk.value = bulk
  deleteOpen.value = true
}

function confirmDelete() {
  deleteOpen.value = false
  if (deleteBulk.value) clearSelection() // 更新後は選択を解除する（F-09）
}

// 一括更新の「適用」。更新後は選択が解除される（F-09）
function applyBulk() {
  clearSelection()
}
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
    <SummaryPanel
      :summary="summary"
      :period-note="periodNote(applied, month)"
      @open-budget="budgetModalOpen = true"
    />
    <CategoryBreakdown :categories="summary.categories" />

    <SearchBar
      :categories="dummyCategories"
      @search="applied = $event"
      @clear="applied = emptyConditions()"
    />

    <!-- 選択モードでは、件数表示と追加・選択ボタンの並びを一括操作バーに置き換える -->
    <BulkActionBar
      v-if="selectMode"
      :selected-count="selectedCount"
      :selected-type="selectedType"
      :categories="dummyCategories"
      @apply="applyBulk"
      @delete="openDeleteDialog(true)"
      @done="finishSelectMode"
    />
    <EntryListHead v-else :count-label="count" @add="openAddModal" @select="selectMode = true" />
    <EntryTable
      :entries="entries"
      :loading="loading"
      :empty-message="emptyMessage(applied)"
      :select-mode="selectMode"
      :selected-ids="selectedIds"
      @edit="openEditModal"
      @delete="openDeleteDialog(false)"
      @toggle="toggleRow"
      @toggle-all="toggleAll"
    />

    <EntryFormModal
      :open="entryModalOpen"
      :entry="editingEntry"
      :categories="dummyCategories"
      :default-date="defaultEntryDate(month)"
      @close="entryModalOpen = false"
      @save="entryModalOpen = false"
    />
    <BudgetModal
      :open="budgetModalOpen"
      :month="month"
      :budget="summary.budget"
      @close="budgetModalOpen = false"
      @save="budgetModalOpen = false"
    />
    <ConfirmDialog
      :open="deleteOpen"
      :message="deleteMessage"
      @cancel="deleteOpen = false"
      @confirm="confirmDelete"
    />
  </div>
</template>
