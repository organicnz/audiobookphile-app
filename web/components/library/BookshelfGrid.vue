<template>
  <div>
    <!-- Loading skeleton -->
    <div
      v-if="loading"
      class="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6"
      aria-busy="true"
      aria-label="Loading library items"
    >
      <div
        v-for="n in skeletonCount"
        :key="n"
        class="flex flex-col overflow-hidden rounded-lg bg-slate-800 shadow-md"
        aria-hidden="true"
      >
        <!-- Cover skeleton -->
        <div class="aspect-square w-full animate-pulse bg-slate-700" />
        <!-- Text skeleton -->
        <div class="flex flex-col gap-1.5 p-2">
          <div class="h-3 w-4/5 animate-pulse rounded bg-slate-700" />
          <div class="h-2.5 w-3/5 animate-pulse rounded bg-slate-700" />
        </div>
      </div>
    </div>

    <!-- Empty state -->
    <div
      v-else-if="items.length === 0"
      class="flex flex-col items-center justify-center py-24 text-center"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class="mb-4 h-16 w-16 text-slate-600"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
        stroke-width="1"
        aria-hidden="true"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25"
        />
      </svg>
      <p class="text-lg font-semibold text-slate-400">No items found</p>
      <p class="mt-1 text-sm text-slate-500">
        {{ emptyMessage }}
      </p>
    </div>

    <!-- Grid -->
    <div
      v-else
      class="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6"
      role="list"
      aria-label="Library items"
    >
      <div
        v-for="item in items"
        :key="item.id"
        role="listitem"
      >
        <BookCard
          :item="item"
          :progress="progressMap.get(item.id) ?? null"
          :is-downloaded="downloadedIds.has(item.id)"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { LibraryItem, MediaProgress } from '~/types'

const props = defineProps<{
  items: LibraryItem[]
  loading?: boolean
  /** Map of item id → MediaProgress for progress badges */
  progressMap?: Map<string, MediaProgress>
  /** Set of item ids that have been downloaded */
  downloadedIds?: Set<string>
  /** Custom empty state message */
  emptyMessage?: string
}>()

const skeletonCount = 12

const progressMap = computed(() => props.progressMap ?? new Map<string, MediaProgress>())
const downloadedIds = computed(() => props.downloadedIds ?? new Set<string>())
const emptyMessage = computed(
  () => props.emptyMessage ?? 'Upload some audiobooks to get started.'
)
</script>
