<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import type { Category, Entry, EntryPayload } from '../types'
import {
  toEntryPayload,
  validateEntryForm,
  type EntryFormErrors,
  type EntryFormValues,
} from '../utils/validation'
import ModalDialog from './ModalDialog.vue'

// 収支入力モーダル（S-02）。追加と編集で同じモーダルを使い、タイトルと初期値だけを変える。
// 検証は「保存」を押した時点で行い、誤りがあれば保存せず該当欄の下にメッセージを出す
const props = defineProps<{
  open: boolean
  /** 編集する明細。null なら追加 */
  entry: Entry | null
  categories: Category[]
  /** 追加時の日付の初期値 */
  defaultDate: string
  /** 送信中。保存を無効にし、閉じる操作も無効にする（N-22） */
  busy: boolean
  /** API が返した項目ごとのエラー（400）。該当欄の下に出す */
  serverErrors: EntryFormErrors | null
  /** 項目に紐づかない失敗（404・500・通信失敗など）。モーダル内の上部に出す */
  serverMessage: string | null
}>()
const emit = defineEmits<{ close: []; save: [payload: EntryPayload] }>()

const form = reactive<EntryFormValues>({ entry_date: '', category_id: null, amount: '', memo: '' })
const errors = ref<EntryFormErrors>({})

// 開くたびに入力欄とエラーを初期状態に戻す（前回の入力を持ち越さない）
watch(
  () => props.open,
  (open) => {
    if (!open) return
    errors.value = {}
    form.entry_date = props.entry?.entry_date ?? props.defaultDate
    form.category_id = props.entry?.category_id ?? null
    form.amount = props.entry ? String(props.entry.amount) : ''
    form.memo = props.entry?.memo ?? ''
  },
  { immediate: true },
)

const isEdit = computed(() => props.entry !== null)

// 追加時は収入・支出の両方をグループ分けして出す。編集時は元のレコードと同じ収支区分のグループだけ
// （区分をまたぐ変更は 400 になるため。docs/features.md F-06）
const groups = computed(() => {
  const all = [
    { label: '支出', type: 'EXPENSE' as const },
    { label: '収入', type: 'INCOME' as const },
  ]
  return all
    .filter((g) => !props.entry || g.type === props.entry.category_type)
    .map((g) => ({
      label: g.label,
      categories: props.categories.filter((c) => c.category_type === g.type),
    }))
})

// API が返した項目ごとのエラーを、入力欄の下に出す
watch(
  () => props.serverErrors,
  (serverErrors) => {
    if (serverErrors) errors.value = { ...serverErrors }
  },
)

function clearError(field: keyof EntryFormValues) {
  delete errors.value[field]
}

// type="number" の入力欄に v-model を使うと、Vue が値を数値に変換してしまう。
// 「1e3」や「12.5」を文字列のまま検証にかけるため（金額は整数のみ）、入力欄の値をそのまま持つ
function onAmountInput(event: Event) {
  form.amount = (event.target as HTMLInputElement).value
  clearError('amount')
}

function save() {
  if (props.busy) return
  errors.value = validateEntryForm(form)
  if (Object.keys(errors.value).length > 0) return
  emit('save', toEntryPayload(form))
}
</script>

<template>
  <ModalDialog
    :open="open"
    :title="isEdit ? '収支を編集' : '収支を追加'"
    :busy="busy"
    @close="emit('close')"
  >
    <form novalidate @submit.prevent="save">
      <div class="modal-body">
        <span v-if="serverMessage" class="field-error" role="alert">{{ serverMessage }}</span>
        <div class="field">
          <label for="entry-date">日付<span class="required">必須</span></label>
          <!-- showModal() は既定で先頭の「×」にフォーカスするため、autofocus で最初の入力欄に置く（N-21） -->
          <input
            id="entry-date"
            v-model="form.entry_date"
            type="date"
            autofocus
            :class="{ invalid: errors.entry_date }"
            @input="clearError('entry_date')"
          />
          <span v-if="errors.entry_date" class="field-error">{{ errors.entry_date }}</span>
        </div>
        <div class="field">
          <label for="entry-category">カテゴリ<span class="required">必須</span></label>
          <select
            id="entry-category"
            v-model="form.category_id"
            :class="{ invalid: errors.category_id }"
            @change="clearError('category_id')"
          >
            <option :value="null">選択してください</option>
            <optgroup v-for="group in groups" :key="group.label" :label="group.label">
              <option v-for="c in group.categories" :key="c.id" :value="c.id">{{ c.name }}</option>
            </optgroup>
          </select>
          <span v-if="errors.category_id" class="field-error">{{ errors.category_id }}</span>
        </div>
        <div class="field">
          <label for="entry-amount">金額<span class="required">必須</span></label>
          <input
            id="entry-amount"
            :value="form.amount"
            type="number"
            :class="{ invalid: errors.amount }"
            @input="onAmountInput"
          />
          <span v-if="errors.amount" class="field-error">{{ errors.amount }}</span>
        </div>
        <div class="field">
          <label for="entry-memo">メモ</label>
          <input
            id="entry-memo"
            v-model="form.memo"
            type="text"
            placeholder="任意・200文字以内"
            :class="{ invalid: errors.memo }"
            @input="clearError('memo')"
          />
          <span v-if="errors.memo" class="field-error">{{ errors.memo }}</span>
        </div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn" :disabled="busy" @click="emit('close')">
          キャンセル
        </button>
        <button type="submit" class="btn btn-primary" :disabled="busy">保存</button>
      </div>
    </form>
  </ModalDialog>
</template>
