<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import {
  ApiError,
  asApiError,
  bulkDeleteEntries,
  bulkUpdateEntries,
  createEntry,
  deleteEntry,
  fetchCategories,
  fetchEntries,
  fetchSummary,
  saveBudget,
  updateEntry,
} from './api'
import BudgetModal from './components/BudgetModal.vue'
import BulkActionBar from './components/BulkActionBar.vue'
import CategoryBreakdown from './components/CategoryBreakdown.vue'
import ConfirmDialog from './components/ConfirmDialog.vue'
import EntryFormModal from './components/EntryFormModal.vue'
import EntryListHead from './components/EntryListHead.vue'
import EntryTable from './components/EntryTable.vue'
import ErrorBanner from './components/ErrorBanner.vue'
import MonthNav from './components/MonthNav.vue'
import SearchBar from './components/SearchBar.vue'
import SummaryPanel from './components/SummaryPanel.vue'
import type { Category, Entry, EntryPayload, SearchConditions, Summary } from './types'
import {
  bulkUpdateMessage,
  countLabel,
  emptyConditions,
  emptyMessage,
  isPeriodOutsideMonth,
  periodNote,
} from './utils/entryList'
import { currentMonth, defaultEntryDate, shiftMonth } from './utils/format'
import type { EntryFormErrors } from './utils/validation'

// 状態管理ライブラリは入れず、ref / computed で持つ（docs/tech-stack.md）。
// 取得系・更新系ともに実際の API に繋いでいる。更新に成功したら、画面の値は API から取り直す
// （docs/screens.md「更新に成功したあとの画面」）。
const month = ref(currentMonth())

// 反映済みの検索条件。検索に成功した時点で変わり、月を切り替えても保持される（docs/screens.md「検索条件の扱い」）
const applied = ref<SearchConditions>(emptyConditions())

type Status = 'loading' | 'ready' | 'error'

const categories = ref<Category[]>([])

// サマリーと内訳は対象月全体の値で、検索条件の影響を受けない（F-08）
const summary = ref<Summary | null>(null)
const summaryStatus = ref<Status>('loading')

const entries = ref<Entry[]>([])
const entriesStatus = ref<Status>('loading')

// エラーバナー。次の操作（月切替・検索など）を始めた時点で消え、失敗すれば改めて出す（docs/screens.md「エラーの表示」）
const banner = ref<string | null>(null)
// 検索の 400（件数超過など）。検索バーの下に出す
const searchError = ref<string | null>(null)

function showError(error: unknown) {
  // ApiError の message は、そのままバナーに出す文言になっている（src/api/client.ts）
  banner.value = asApiError(error).message
}

async function loadCategories() {
  try {
    categories.value = await fetchCategories()
  } catch (error) {
    showError(error)
  }
}

// 古い応答が新しい応答を上書きしないよう、それぞれ最後の要求の結果だけを採用する
let latestSummary = 0
async function loadSummary() {
  const request = ++latestSummary
  summaryStatus.value = 'loading'
  try {
    const result = await fetchSummary(month.value)
    if (request !== latestSummary) return
    summary.value = result
    summaryStatus.value = 'ready'
  } catch (error) {
    if (request !== latestSummary) return
    // 直前の月の値を残さない（対象月の表示と食い違うため）
    summary.value = null
    summaryStatus.value = 'error'
    showError(error)
  }
}

// 検索の 400 で「直前の一覧」に戻すために、最後に確定した状態を覚えておく
let settledEntriesStatus: Status = 'ready'
let latestEntries = 0

/**
 * 明細を取得する。成功したら一覧と反映済みの条件を同時に更新する。
 * 検索の 400（件数超過など）は、直前の一覧と反映済みの条件を保持したまま、検索バーの下にメッセージを出す。
 */
async function loadEntries(conditions: SearchConditions) {
  const request = ++latestEntries
  entriesStatus.value = 'loading'
  try {
    const result = await fetchEntries(month.value, conditions)
    if (request !== latestEntries) return
    entries.value = result
    applied.value = conditions
    entriesStatus.value = settledEntriesStatus = 'ready'
    clearSelection() // 一覧が変わるので選択を解除する（docs/screens.md「選択モードの扱い」）
  } catch (error) {
    if (request !== latestEntries) return
    if (error instanceof ApiError && error.kind === 'validation') {
      entriesStatus.value = settledEntriesStatus
      searchError.value = error.message
      return
    }
    entries.value = []
    clearSelection()
    entriesStatus.value = settledEntriesStatus = 'error'
    showError(error)
  }
}

// 次の操作を始めた時点で、前のエラーの表示を消す
function beginOperation() {
  banner.value = null
  searchError.value = null
}

// 月が変わるたびに、サマリー・内訳・明細をすべて取り直す（F-04）。初回も同じ
function refresh() {
  beginOperation()
  if (categories.value.length === 0) loadCategories()
  loadSummary()
  loadEntries(applied.value)
}
watch(month, refresh, { immediate: true })

function search(conditions: SearchConditions) {
  beginOperation()
  loadEntries(conditions)
}

function clearSearch() {
  beginOperation()
  loadEntries(emptyConditions())
}

// 件数表示。母数（サマリーの entry_count）が要るのは「明細 12件」「12件中 3件」で、
// 対象月の外を含む期間検索は母数を出さない（docs/screens.md）ため、サマリーの取得に失敗していても出せる
const count = computed(() => {
  if (entriesStatus.value !== 'ready') return ''
  if (summary.value && summaryStatus.value === 'ready') {
    return countLabel(applied.value, month.value, summary.value.entry_count, entries.value.length)
  }
  return isPeriodOutsideMonth(applied.value, month.value)
    ? countLabel(applied.value, month.value, 0, entries.value.length)
    : ''
})

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

// --- 更新系（F-02・F-05〜F-07・F-09）
// 送信中は、保存・削除する・変更するを無効にし、閉じる操作も無効にする（N-22。docs/screens.md「送信中の扱い」）
const sending = ref(false)

async function send(action: () => Promise<unknown>): Promise<ApiError | null> {
  sending.value = true
  try {
    await action()
    return null
  } catch (error) {
    return asApiError(error)
  } finally {
    sending.value = false
  }
}

// 更新に成功したら、サマリー・内訳・明細一覧を取り直す。明細は反映済みの検索条件のまま取り直し、選択は解除される。
// 予算設定は明細が変わらないので、サマリーと内訳だけ
function reloadAfterUpdate(scope: 'all' | 'summary' = 'all') {
  loadSummary()
  if (scope === 'all') loadEntries(applied.value)
}

/**
 * 400 の `errors` を、入力欄の下に出す分と、モーダル内の上部に出す分に分ける。
 * 項目に紐づくエラーは該当欄の下に、それ以外（項目のないエラー、404・500・通信失敗）は上部に出す
 */
function splitErrors<K extends string>(error: ApiError, fields: readonly K[]) {
  const known: Partial<Record<K, string>> = {}
  let unknown = false
  for (const [key, message] of Object.entries(error.errors ?? {})) {
    if ((fields as readonly string[]).includes(key)) known[key as K] = message
    else unknown = true
  }
  const hasKnown = Object.keys(known).length > 0
  return {
    fields: hasKnown ? known : null,
    message: hasKnown && !unknown ? null : error.message,
  }
}

// --- 収支入力モーダル（S-02）。編集中の明細は、閉じるときの表示崩れを避けるため開閉とは別に持つ
const entryModalOpen = ref(false)
const editingEntry = ref<Entry | null>(null)
const entryServerErrors = ref<EntryFormErrors | null>(null)
const entryServerMessage = ref<string | null>(null)

function openEntryModal(entry: Entry | null) {
  editingEntry.value = entry
  entryServerErrors.value = null
  entryServerMessage.value = null
  entryModalOpen.value = true
}

const openAddModal = () => openEntryModal(null)
const openEditModal = (entry: Entry) => openEntryModal(entry)

async function saveEntry(payload: EntryPayload) {
  beginOperation()
  entryServerErrors.value = null
  entryServerMessage.value = null
  const editing = editingEntry.value
  const error = await send(() =>
    editing ? updateEntry(editing.id, payload) : createEntry(payload),
  )
  if (!error) {
    entryModalOpen.value = false
    reloadAfterUpdate()
    return
  }
  const { fields, message } = splitErrors(error, ['entry_date', 'category_id', 'amount', 'memo'])
  entryServerErrors.value = fields
  entryServerMessage.value = message
  // 編集の 404（別の操作ですでに消えている）は、画面の状態がずれているので取り直す
  if (error.kind === 'not_found') reloadAfterUpdate()
}

// --- 予算設定モーダル（S-04）
const budgetModalOpen = ref(false)
const budgetServerError = ref<string | null>(null)
const budgetServerMessage = ref<string | null>(null)

function openBudgetModal() {
  budgetServerError.value = null
  budgetServerMessage.value = null
  budgetModalOpen.value = true
}

async function saveBudgetAmount(amount: number) {
  beginOperation()
  budgetServerError.value = null
  budgetServerMessage.value = null
  const error = await send(() => saveBudget(month.value, amount))
  if (!error) {
    budgetModalOpen.value = false
    reloadAfterUpdate('summary')
    return
  }
  const { fields, message } = splitErrors(error, ['amount'])
  budgetServerError.value = fields?.amount ?? null
  budgetServerMessage.value = message
}

// --- 削除確認ダイアログ（S-03）。単体は行の削除ボタン、一括は一括操作バーの「削除」から開く
const deleteOpen = ref(false)
const deleteBulk = ref(false)
const deletingEntry = ref<Entry | null>(null)
const deleteMessage = computed(() =>
  deleteBulk.value ? `${selectedCount.value}件のデータを削除します。` : 'このデータを削除します。',
)

function openDeleteDialog(entry: Entry) {
  deleteBulk.value = false
  deletingEntry.value = entry
  deleteOpen.value = true
}

function openBulkDeleteDialog() {
  deleteBulk.value = true
  deleteOpen.value = true
}

// 失敗したら、ダイアログを閉じてエラーバナーを出し、一覧とサマリーを取り直す（画面の状態がずれている可能性があるため）
async function confirmDelete() {
  beginOperation()
  const ids = [...selectedIds.value]
  const entry = deletingEntry.value
  const error = await send(() =>
    deleteBulk.value ? bulkDeleteEntries(ids) : deleteEntry(entry!.id),
  )
  deleteOpen.value = false
  if (error) showError(error)
  reloadAfterUpdate()
}

// --- 一括更新の確認ダイアログ（N-23）。「適用」を押すと、変更内容を示して確認する
const applyOpen = ref(false)
const pendingChanges = ref<{ category_id: number | null; entry_date: string }>({
  category_id: null,
  entry_date: '',
})
const applyMessage = computed(() =>
  bulkUpdateMessage(
    selectedCount.value,
    categories.value.find((c) => c.id === pendingChanges.value.category_id)?.name ?? null,
    pendingChanges.value.entry_date,
  ),
)

function openApplyDialog(changes: { category_id: number | null; entry_date: string }) {
  pendingChanges.value = changes
  applyOpen.value = true
}

async function confirmApply() {
  beginOperation()
  const ids = [...selectedIds.value]
  const { category_id, entry_date } = pendingChanges.value
  // 指定した項目だけを送る（両方指定も可）
  const changes = {
    ...(category_id !== null && { category_id }),
    ...(entry_date !== '' && { entry_date }),
  }
  const error = await send(() => bulkUpdateEntries(ids, changes))
  applyOpen.value = false
  if (error) showError(error)
  reloadAfterUpdate()
}
</script>

<template>
  <div class="app">
    <div class="header">
      <h1>家計簿</h1>
    </div>

    <ErrorBanner v-if="banner" :message="banner" @close="banner = null" />

    <MonthNav
      :month="month"
      @prev="month = shiftMonth(month, -1)"
      @next="month = shiftMonth(month, 1)"
    />
    <template v-if="summary && summaryStatus === 'ready'">
      <SummaryPanel
        :summary="summary"
        :period-note="periodNote(applied, month)"
        @open-budget="openBudgetModal"
      />
      <CategoryBreakdown :categories="summary.categories" />
    </template>
    <!-- 取得中・取得失敗のときは、直前の月の値を残さず、領域ごとその旨を示す -->
    <div v-else class="card">
      <div v-if="summaryStatus === 'error'" class="empty">読み込めませんでした</div>
      <div v-else class="loading" role="status">読み込み中…</div>
    </div>

    <SearchBar
      :categories="categories"
      :server-error="searchError"
      @search="search"
      @clear="clearSearch"
    />

    <!-- 選択モードでは、件数表示と追加・選択ボタンの並びを一括操作バーに置き換える -->
    <BulkActionBar
      v-if="selectMode"
      :selected-count="selectedCount"
      :selected-type="selectedType"
      :categories="categories"
      @apply="openApplyDialog"
      @delete="openBulkDeleteDialog"
      @done="finishSelectMode"
    />
    <EntryListHead v-else :count-label="count" @add="openAddModal" @select="selectMode = true" />
    <EntryTable
      :entries="entries"
      :loading="entriesStatus === 'loading'"
      :error="entriesStatus === 'error'"
      :empty-message="emptyMessage(applied)"
      :select-mode="selectMode"
      :selected-ids="selectedIds"
      @edit="openEditModal"
      @delete="openDeleteDialog"
      @toggle="toggleRow"
      @toggle-all="toggleAll"
    />

    <EntryFormModal
      :open="entryModalOpen"
      :entry="editingEntry"
      :categories="categories"
      :default-date="defaultEntryDate(month)"
      :busy="sending"
      :server-errors="entryServerErrors"
      :server-message="entryServerMessage"
      @close="entryModalOpen = false"
      @save="saveEntry"
    />
    <BudgetModal
      :open="budgetModalOpen"
      :month="month"
      :budget="summary?.budget ?? null"
      :busy="sending"
      :server-error="budgetServerError"
      :server-message="budgetServerMessage"
      @close="budgetModalOpen = false"
      @save="saveBudgetAmount"
    />
    <ConfirmDialog
      :open="deleteOpen"
      title="削除の確認"
      :message="deleteMessage"
      hint="この操作は取り消せません。"
      confirm-label="削除する"
      danger
      :busy="sending"
      @cancel="deleteOpen = false"
      @confirm="confirmDelete"
    />
    <ConfirmDialog
      :open="applyOpen"
      title="変更の確認"
      :message="applyMessage"
      hint="変更前の値には戻せません。"
      confirm-label="変更する"
      :busy="sending"
      @cancel="applyOpen = false"
      @confirm="confirmApply"
    />
  </div>
</template>
