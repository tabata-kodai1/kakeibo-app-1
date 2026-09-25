<script setup lang="ts">
import type { Entry } from '../types'
import EntryRow from './EntryRow.vue'

// 明細一覧のテーブル（F-04）。読み込み中・0 件のときは表の代わりにメッセージを出す
defineProps<{ entries: Entry[]; loading: boolean; emptyMessage: string }>()
const emit = defineEmits<{ edit: [entry: Entry]; delete: [entry: Entry] }>()
</script>

<template>
  <div class="table-wrap">
    <div v-if="loading" class="loading" role="status">読み込み中…</div>
    <div v-else-if="entries.length === 0" class="empty">{{ emptyMessage }}</div>
    <table v-else>
      <thead>
        <tr>
          <th class="col-date">日付</th>
          <th class="col-category">カテゴリ</th>
          <th class="col-amount">金額</th>
          <th>メモ</th>
          <th class="col-actions">操作</th>
        </tr>
      </thead>
      <tbody>
        <EntryRow
          v-for="entry in entries"
          :key="entry.id"
          :entry="entry"
          @edit="emit('edit', $event)"
          @delete="emit('delete', $event)"
        />
      </tbody>
    </table>
  </div>
</template>
