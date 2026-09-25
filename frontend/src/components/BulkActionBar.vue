<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { Category, CategoryType } from '../types'

// 一括操作バー（F-09）。選択モードの間は、選択が 0 件でも表示する。
// 「完了」がバーの中にあり、0 件で隠すと選択モードから戻れなくなるため（docs/screens.md）。
const props = defineProps<{
  selectedCount: number
  /** 選択行の収支区分。0 件なら null、支出と収入が混在していれば 'MIXED' */
  selectedType: CategoryType | 'MIXED' | null
  categories: Category[]
}>()
const emit = defineEmits<{
  apply: [changes: { category_id: number | null; entry_date: string }]
  delete: []
  done: []
}>()

const category = ref<number | null>(null)
const date = ref('')

// 一括カテゴリの候補は、選択行と同じ収支区分のカテゴリだけ（別の区分は 400 になるため、選べない状態にしておく）
const options = computed(() =>
  props.selectedType === 'EXPENSE' || props.selectedType === 'INCOME'
    ? props.categories.filter((c) => c.category_type === props.selectedType)
    : [],
)
const groupLabel = computed(() => (props.selectedType === 'INCOME' ? '収入' : '支出'))
const categoryDisabled = computed(() => options.value.length === 0)
const reason = computed(() =>
  props.selectedType === 'MIXED' ? '支出と収入が混在しているため、カテゴリは変更できません' : null,
)

// 「適用」は、1 件以上選択され、カテゴリまたは日付の少なくとも一方が入力されているときだけ有効
const canApply = computed(
  () => props.selectedCount > 0 && (category.value !== null || date.value !== ''),
)

// 選択の区分が変わったら、選んでいたカテゴリは無効になりうるので外す。選択が空になったら入力もリセットする
watch(
  () => props.selectedType,
  () => (category.value = null),
)
watch(
  () => props.selectedCount,
  (count) => {
    if (count === 0) date.value = ''
  },
)

function apply() {
  emit('apply', { category_id: category.value, entry_date: date.value })
}
</script>

<template>
  <div class="card bulk-bar">
    <span class="count">{{ selectedCount }}件選択中</span>
    <select v-model="category" :disabled="categoryDisabled" aria-label="カテゴリを変更">
      <option :value="null">カテゴリを変更…</option>
      <optgroup v-if="options.length > 0" :label="groupLabel">
        <option v-for="c in options" :key="c.id" :value="c.id">{{ c.name }}</option>
      </optgroup>
    </select>
    <span v-if="reason" class="reason">{{ reason }}</span>
    <input v-model="date" type="date" :disabled="selectedCount === 0" aria-label="日付を変更" />
    <button type="button" class="btn" :disabled="!canApply" @click="apply">適用</button>
    <span class="spacer"></span>
    <button
      type="button"
      class="btn btn-danger"
      :disabled="selectedCount === 0"
      @click="emit('delete')"
    >
      削除
    </button>
    <button type="button" class="btn" @click="emit('done')">完了</button>
  </div>
</template>
