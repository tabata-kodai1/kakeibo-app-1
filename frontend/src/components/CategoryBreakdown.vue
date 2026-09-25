<script setup lang="ts">
import type { CategorySummary } from '../types'
import { formatAmount } from '../utils/format'

// カテゴリ別集計（F-03）。支出カテゴリのみ・金額の降順で渡される
defineProps<{ categories: CategorySummary[] }>()
</script>

<template>
  <div class="card">
    <div class="card-title">支出の内訳</div>
    <div v-if="categories.length === 0" class="empty">支出がありません</div>
    <div v-for="row in categories" v-else :key="row.category_id" class="breakdown-row">
      <span class="cat">{{ row.category_name }}</span>
      <span class="amt">{{ formatAmount(row.amount) }}</span>
      <span class="bar"><span :style="{ width: `${row.rate}%` }"></span></span>
      <span class="pct">{{ row.rate }}%</span>
    </div>
  </div>
</template>
