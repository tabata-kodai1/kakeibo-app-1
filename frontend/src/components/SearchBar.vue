<script setup lang="ts">
import { ref } from 'vue'
import type { Category, SearchConditions } from '../types'
import { emptyConditions, isPeriodReversed } from '../utils/entryList'

// 検索バー（F-08）。入力中の値（draft）はここで持ち、「検索」を押した時点の値だけを親へ渡す。
// 親が持つ「反映済みの条件」は、入力途中では変わらない（docs/screens.md「検索条件の扱い」）
defineProps<{ categories: Category[] }>()
const emit = defineEmits<{ search: [conditions: SearchConditions]; clear: [] }>()

const draft = ref<SearchConditions>(emptyConditions())
const error = ref<string | null>(null)

function search() {
  // from > to のときは反映済みの条件を変えず、エラーだけ出す（直前の一覧を保持する）
  if (isPeriodReversed(draft.value)) {
    error.value = '開始日は終了日より前の日付を指定してください'
    return
  }
  error.value = null
  emit('search', { ...draft.value })
}

function clear() {
  draft.value = emptyConditions()
  error.value = null
  emit('clear')
}
</script>

<template>
  <div>
    <form class="card search" @submit.prevent="search">
      <div class="field">
        <label for="search-category">カテゴリ</label>
        <select id="search-category" v-model="draft.category_id">
          <option :value="null">すべて</option>
          <optgroup label="支出">
            <option
              v-for="c in categories.filter((c) => c.category_type === 'EXPENSE')"
              :key="c.id"
              :value="c.id"
            >
              {{ c.name }}
            </option>
          </optgroup>
          <optgroup label="収入">
            <option
              v-for="c in categories.filter((c) => c.category_type === 'INCOME')"
              :key="c.id"
              :value="c.id"
            >
              {{ c.name }}
            </option>
          </optgroup>
        </select>
      </div>
      <div class="field">
        <label for="search-keyword">キーワード</label>
        <input id="search-keyword" v-model="draft.keyword" type="text" placeholder="メモを検索" />
      </div>
      <div class="field">
        <label for="search-from">期間（月をまたいで検索）</label>
        <div class="range">
          <input id="search-from" v-model="draft.from" type="date" :class="{ invalid: error }" />
          <span>〜</span>
          <input v-model="draft.to" type="date" aria-label="終了日" :class="{ invalid: error }" />
        </div>
      </div>
      <div class="search-actions">
        <button type="submit" class="btn btn-primary">検索</button>
        <button type="button" class="btn" @click="clear">クリア</button>
      </div>
    </form>
    <div v-if="error" class="field-error" role="alert">{{ error }}</div>
  </div>
</template>
