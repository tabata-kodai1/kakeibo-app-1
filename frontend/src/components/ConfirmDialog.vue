<script setup lang="ts">
import ModalDialog from './ModalDialog.vue'

// 確認ダイアログ。削除（S-03）と一括更新（N-23）で使い、見出し・本文・ボタンだけを差し替える。
// 取り消せない操作なので、初期フォーカスは「キャンセル」に置く（Enter だけで実行されないように）。
// 送信中（busy）は「実行」を無効にし、閉じる操作も無効にする
withDefaults(
  defineProps<{
    open: boolean
    title: string
    message: string
    /** 本文の下に出す注意書き */
    hint: string
    confirmLabel: string
    /** 実行ボタンを警告色にする（削除）。一括更新は通常の色 */
    danger?: boolean
    busy?: boolean
  }>(),
  { danger: false, busy: false },
)
const emit = defineEmits<{ cancel: []; confirm: [] }>()
</script>

<template>
  <ModalDialog :open="open" :title="title" :closable="false" :busy="busy" @close="emit('cancel')">
    <div class="modal-body">
      <p>{{ message }}</p>
      <p class="hint">{{ hint }}</p>
    </div>
    <div class="modal-footer">
      <button type="button" class="btn" autofocus :disabled="busy" @click="emit('cancel')">
        キャンセル
      </button>
      <button
        type="button"
        class="btn"
        :class="danger ? 'btn-danger' : 'btn-primary'"
        :disabled="busy"
        @click="emit('confirm')"
      >
        {{ confirmLabel }}
      </button>
    </div>
  </ModalDialog>
</template>
