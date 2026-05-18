<template>
  <NuxtLink
    :to="`/item/${item.id}`"
    class="group relative flex flex-col overflow-hidden rounded-lg bg-slate-800 shadow-md transition-transform duration-200 hover:scale-[1.02] hover:shadow-xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500"
    :aria-label="`${item.title}${item.author ? ` by ${item.author}` : ''}`"
  >
    <!-- Cover image -->
    <div class="relative aspect-square w-full overflow-hidden bg-slate-700">
      <img
        v-if="coverUrl"
        :src="coverUrl"
        :alt="`Cover for ${item.title}`"
        class="h-full w-full object-cover transition-opacity duration-300"
        loading="lazy"
        @error="onImageError"
      />
      <!-- Placeholder when no cover or image fails to load -->
      <div
        v-else
        class="flex h-full w-full items-center justify-center bg-gradient-to-br from-slate-700 to-slate-600"
        aria-hidden="true"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-12 w-12 text-slate-500"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          stroke-width="1.5"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25"
          />
        </svg>
      </div>

      <!-- Progress badge -->
      <div
        v-if="progressPercent !== null"
        class="absolute bottom-0 left-0 right-0 h-1 bg-slate-600"
        role="progressbar"
        :aria-valuenow="progressPercent"
        aria-valuemin="0"
        aria-valuemax="100"
        :aria-label="`${progressPercent}% complete`"
      >
        <div
          class="h-full bg-indigo-500 transition-all duration-300"
          :style="{ width: `${progressPercent}%` }"
        />
      </div>

      <!-- Progress percentage badge (shown on hover or when > 0) -->
      <div
        v-if="progressPercent !== null && progressPercent > 0"
        class="absolute right-1.5 top-1.5 rounded bg-black/70 px-1.5 py-0.5 text-xs font-semibold text-white"
        aria-hidden="true"
      >
        {{ progressPercent }}%
      </div>

      <!-- Downloaded indicator -->
      <div
        v-if="isDownloaded"
        class="absolute left-1.5 top-1.5 rounded bg-emerald-600/90 p-1"
        title="Downloaded for offline playback"
        aria-label="Downloaded for offline playback"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-3.5 w-3.5 text-white"
          viewBox="0 0 20 20"
          fill="currentColor"
          aria-hidden="true"
        >
          <path
            fill-rule="evenodd"
            d="M3 17a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm3.293-7.707a1 1 0 011.414 0L9 10.586V3a1 1 0 112 0v7.586l1.293-1.293a1 1 0 111.414 1.414l-3 3a1 1 0 01-1.414 0l-3-3a1 1 0 010-1.414z"
            clip-rule="evenodd"
          />
        </svg>
      </div>
    </div>

    <!-- Metadata -->
    <div class="flex flex-1 flex-col gap-0.5 p-2">
      <p
        class="line-clamp-2 text-sm font-semibold leading-tight text-slate-100 group-hover:text-indigo-300 transition-colors"
        :title="item.title"
      >
        {{ item.title }}
      </p>
      <p
        v-if="item.author"
        class="line-clamp-1 text-xs text-slate-400"
        :title="item.author"
      >
        {{ item.author }}
      </p>
      <p
        v-if="item.series"
        class="line-clamp-1 text-xs text-slate-500 italic"
        :title="seriesLabel"
      >
        {{ seriesLabel }}
      </p>
    </div>
  </NuxtLink>
</template>

<script setup lang="ts">
import type { LibraryItem, MediaProgress } from '~/types'

const props = defineProps<{
  item: LibraryItem
  /** Optional progress record for this item */
  progress?: MediaProgress | null
  /** Whether the item has been downloaded for offline use */
  isDownloaded?: boolean
}>()

const supabase = useSupabaseClient()

// ─── Cover URL ───────────────────────────────────────────────────────────────

const imageError = ref(false)

const coverUrl = computed<string | null>(() => {
  if (imageError.value || !props.item.cover_image_path) return null
  // cover_image_path is stored as a path in the public `covers` bucket
  const { data } = supabase.storage
    .from('covers')
    .getPublicUrl(props.item.cover_image_path)
  return data?.publicUrl ?? null
})

function onImageError() {
  imageError.value = true
}

// ─── Progress ────────────────────────────────────────────────────────────────

const progressPercent = computed<number | null>(() => {
  if (!props.progress) return null
  return Math.floor(props.progress.progress * 100)
})

// ─── Series label ────────────────────────────────────────────────────────────

const seriesLabel = computed<string>(() => {
  if (!props.item.series) return ''
  if (props.item.series_sequence) {
    return `${props.item.series} #${props.item.series_sequence}`
  }
  return props.item.series
})
</script>
