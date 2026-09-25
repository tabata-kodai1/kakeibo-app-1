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

function save() {
  error.value = validateBudget(amount.value)
  if (error.value === null) emit('save', Number(amount.value.trim()))
}
</script>

<template>
  <ModalDialog :open="open" :title="`${formatMonthLabel(month)}の予算`" @close="emit('close')">
    <form novalidate @submit.prevent="save">
      <div class="modal-body">
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
        <button type="button" class="btn" @click="emit('close')">キャンセル</button>
        <button type="submit" class="btn btn-primary">保存</button>
      </div>
    </form>
  </ModalDialog>
</template>
