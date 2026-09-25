<script setup lang="ts">
import { onMounted, useId, useTemplateRef, watch } from 'vue'

// 3 種のダイアログ（S-02・S-03・S-04、一括更新の確認）に共通のふるまい。
// HTML 標準の <dialog> + showModal() で開く。Esc での閉じとフォーカストラップは標準で効く（N-21）。
//   - Esc・「×」は、どちらも close を通知する（変更の破棄は親が行う）
//   - 背景（::backdrop）を押しても閉じない。入力途中の誤操作で内容を失わないため（docs/screens.md）
//   - 送信中（busy）は、閉じる操作をすべて無効にする。閉じたあとに結果だけが返ると、
//     画面の状態が分からなくなるため（docs/screens.md「送信中の扱い」）
const props = withDefaults(
  defineProps<{ open: boolean; title: string; closable?: boolean; busy?: boolean }>(),
  { closable: true, busy: false },
)
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

// Esc は、ブラウザが閉じる前に cancel イベントを出す。送信中はここで止める
function onCancel(event: Event) {
  if (props.busy) event.preventDefault()
}

// Esc でブラウザが閉じたとき。props.open がまだ true なら、親の状態を閉じに合わせる。
// ただし cancel を止めても、ブラウザは「ユーザー操作を挟まない 2 回目以降の Esc」を止めさせずに閉じる
// （<dialog> に閉じ込められないようにする仕様）。送信中に閉じられたときは、開き直して結果を見られるようにする
function onClose() {
  if (!props.open) return
  if (props.busy) dialog.value?.showModal()
  else emit('close')
}
</script>

<template>
  <dialog
    ref="dialog"
    class="modal"
    :aria-labelledby="titleId"
    :aria-busy="busy"
    @cancel="onCancel"
    @close="onClose"
  >
    <div class="modal-header">
      <h2 :id="titleId">{{ title }}</h2>
      <button
        v-if="closable"
        type="button"
        class="btn-icon"
        title="閉じる"
        aria-label="閉じる"
        :disabled="busy"
        @click="emit('close')"
      >
        ×
      </button>
    </div>
    <slot />
  </dialog>
</template>
