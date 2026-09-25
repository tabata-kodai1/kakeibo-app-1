<script setup lang="ts">
import { onMounted, useId, useTemplateRef, watch } from 'vue'

// 3 つのモーダル（S-02・S-03・S-04）に共通のふるまい。HTML 標準の <dialog> + showModal() で開く。
// Esc での閉じとフォーカストラップは標準で効く（N-21）。
//   - Esc・「×」は、どちらも close を通知する（変更の破棄は親が行う）
//   - 背景（::backdrop）を押しても閉じない。入力途中の誤操作で内容を失わないため（docs/screens.md）
const props = withDefaults(defineProps<{ open: boolean; title: string; closable?: boolean }>(), {
  closable: true,
})
const emit = defineEmits<{ close: [] }>()

const dialog = useTemplateRef<HTMLDialogElement>('dialog')
const titleId = useId()

function sync() {
  const el = dialog.value
  if (!el) return
  if (props.open && !el.open) el.showModal()
  else if (!props.open && el.open) el.close()
}

onMounted(sync)
watch(() => props.open, sync, { flush: 'post' })

// Esc でブラウザが閉じたとき。props.open がまだ true なら、親の状態を閉じに合わせる
function onClose() {
  if (props.open) emit('close')
}
</script>

<template>
  <dialog ref="dialog" class="modal" :aria-labelledby="titleId" @close="onClose">
    <div class="modal-header">
      <h2 :id="titleId">{{ title }}</h2>
      <button
        v-if="closable"
        type="button"
        class="btn-icon"
        title="閉じる"
        aria-label="閉じる"
        @click="emit('close')"
      >
        ×
      </button>
    </div>
    <slot />
  </dialog>
</template>
