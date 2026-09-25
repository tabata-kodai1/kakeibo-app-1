import js from '@eslint/js'
import globals from 'globals'
import pluginVue from 'eslint-plugin-vue'
import tseslint from 'typescript-eslint'
// 整形は Prettier、検出は ESLint と役割を分ける（docs/tech-stack.md）。
// 書式に関する規則をここで無効化して、両者がぶつからないようにする。
import prettier from 'eslint-config-prettier'

export default tseslint.config(
  { ignores: ['dist/**'] },
  // 対象ブラウザは Chrome のみ（N-01）。fetch などのブラウザ側の API を既知にする
  { languageOptions: { globals: globals.browser } },
  js.configs.recommended,
  tseslint.configs.recommended,
  pluginVue.configs['flat/recommended'],
  {
    files: ['**/*.vue'],
    languageOptions: {
      parserOptions: { parser: tseslint.parser },
    },
  },
  prettier,
)
