<script setup lang="ts">
import ModalDialog from './ModalDialog.vue'

// 削除確認ダイアログ（S-03）。単体削除と一括削除で使い、件数メッセージだけを差し替える。
// 取り消せない操作なので、初期フォーカスは「キャンセル」に置く（Enter だけで削除が実行されないように）
defineProps<{ open: boolean; message: string }>()
const emit = defineEmits<{ cancel: []; confirm: [] }>()
</script>

<template>
  <ModalDialog :open="open" title="削除の確認" :closable="false" @close="emit('cancel')">
    <div class="modal-body">
      <p>{{ message }}</p>
      <p class="hint">この操作は取り消せません。</p>
    </div>
    <div class="modal-footer">
      <button type="button" class="btn" autofocus @click="emit('cancel')">キャンセル</button>
      <button type="button" class="btn btn-danger" @click="emit('confirm')">削除する</button>
    </div>
  </ModalDialog>
</template>
