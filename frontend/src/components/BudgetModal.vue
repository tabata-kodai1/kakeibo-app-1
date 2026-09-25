<script setup lang="ts">
import { ref, watch } from 'vue'
import { formatMonthLabel } from '../utils/format'
import { validateBudget } from '../utils/validation'
import ModalDialog from './ModalDialog.vue'

// 予算設定モーダル（S-04）。予算が未設定の月は入力欄が空、設定済みなら現在の値が入る
const props = defineProps<{
  open: boolean
  /** 対象月（yyyy-MM） */
  month: string
  /** 現在の予算。未設定は null */
  budget: number | null
  /** 送信中。保存を無効にし、閉じる操作も無効にする（N-22） */
  busy: boolean
  /** API が返した予算額のエラー（400） */
  serverError: string | null
  /** 項目に紐づかない失敗（404・500・通信失敗など）。モーダル内の上部に出す */
  serverMessage: string | null
}>()
const emit = defineEmits<{ close: []; save: [amount: number] }>()

const amount = ref('')
const error = ref<string | null>(null)

// 開くたびに初期状態へ戻す
watch(
  () => props.open,
  (open) => {
    if (!open) return
    error.value = null
    amount.value = props.budget === null ? '' : String(props.budget)
  },
  { immediate: true },
)

// type="number" の入力欄に v-model を使うと、Vue が値を数値に変換してしまう。
// 文字列のまま検証にかけるため、入力欄の値をそのまま持つ
function onInput(event: Event) {
  amount.value = (event.target as HTMLInputElement).value
  error.value = null
}

// API が返した予算額のエラーを、入力欄の下に出す
watch(
  () => props.serverError,
  (serverError) => {
    if (serverError) error.value = serverError
  },
)

function save() {
  if (props.busy) return
  error.value = validateBudget(amount.value)
  if (error.value === null) emit('save', Number(amount.value.trim()))
}
</script>

<template>
  <ModalDialog
    :open="open"
    :title="`${formatMonthLabel(month)}の予算`"
    :busy="busy"
    @close="emit('close')"
  >
    <form novalidate @submit.prevent="save">
      <div class="modal-body">
        <span v-if="serverMessage" class="field-error" role="alert">{{ serverMessage }}</span>
        <div class="field">
          <label for="budget-amount">予算額<span class="required">必須</span></label>
          <input
            id="budget-amount"
            :value="amount"
            type="number"
            :class="{ invalid: error }"
            @input="onInput"
          />
          <span v-if="error" class="field-error">{{ error }}</span>
        </div>
        <p class="hint">
          この月に使ってよい支出の上限額を設定します。収入は残額の計算に含まれません。
        </p>
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
