<script setup lang="ts">
import { computed } from 'vue'
import type { Entry } from '../types'
import EntryRow from './EntryRow.vue'

// 明細一覧のテーブル（F-04）。読み込み中・0 件のときは表の代わりにメッセージを出す。
// 選択モード（F-09）では、各行にチェックボックスを出し、行ごとの編集・削除ボタンは隠す
const props = defineProps<{
  entries: Entry[]
  loading: boolean
  emptyMessage: string
  selectMode?: boolean
  selectedIds?: ReadonlySet<number>
}>()
const emit = defineEmits<{
  edit: [entry: Entry]
  delete: [entry: Entry]
  toggle: [id: number]
  'toggle-all': [checked: boolean]
}>()

const selectedCount = computed(
  () => props.entries.filter((e) => props.selectedIds?.has(e.id)).length,
)
const allSelected = computed(
  () => props.entries.length > 0 && selectedCount.value === props.entries.length,
)
// 一部だけ選択されているときは、ヘッダのチェックボックスを中間状態にする
const partiallySelected = computed(() => selectedCount.value > 0 && !allSelected.value)
</script>

<template>
  <div class="table-wrap">
    <div v-if="loading" class="loading" role="status">読み込み中…</div>
    <div v-else-if="entries.length === 0" class="empty">{{ emptyMessage }}</div>
    <table v-else>
      <thead>
        <tr>
          <th v-if="selectMode" class="col-check">
            <input
              type="checkbox"
              aria-label="表示中の全行を選択"
              :checked="allSelected"
              :indeterminate="partiallySelected"
              @change="emit('toggle-all', ($event.target as HTMLInputElement).checked)"
            />
          </th>
          <th class="col-date">日付</th>
          <th class="col-category">カテゴリ</th>
          <th class="col-amount">金額</th>
          <th>メモ</th>
          <th v-if="!selectMode" class="col-actions">操作</th>
        </tr>
      </thead>
      <tbody>
        <EntryRow
          v-for="entry in entries"
          :key="entry.id"
          :entry="entry"
          :select-mode="selectMode"
          :selected="selectedIds?.has(entry.id)"
          @edit="emit('edit', $event)"
          @delete="emit('delete', $event)"
          @toggle="emit('toggle', entry.id)"
        />
      </tbody>
    </table>
  </div>
</template>
