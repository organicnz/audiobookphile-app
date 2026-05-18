<template>
  <div class="flex flex-wrap items-center gap-2 rounded-lg bg-slate-800/60 p-3">
    <!-- Search input -->
    <div class="relative min-w-[180px] flex-1">
      <label for="library-search" class="sr-only">Search library</label>
      <span class="pointer-events-none absolute inset-y-0 left-2.5 flex items-center" aria-hidden="true">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-4 w-4 text-slate-400"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          stroke-width="2"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-4.35-4.35M17 11A6 6 0 115 11a6 6 0 0112 0z" />
        </svg>
      </span>
      <input
        id="library-search"
        v-model="searchInput"
        type="search"
        placeholder="Search title, author, series…"
        class="w-full rounded-md border border-slate-600 bg-slate-700 py-1.5 pl-8 pr-3 text-sm text-slate-100 placeholder-slate-400 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
      />
    </div>

    <!-- Sort field dropdown -->
    <div class="flex items-center gap-1">
      <label for="sort-field" class="sr-only">Sort by</label>
      <select
        id="sort-field"
        v-model="sortField"
        class="rounded-md border border-slate-600 bg-slate-700 py-1.5 pl-2 pr-7 text-sm text-slate-100 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
        @change="emitSort"
      >
        <option value="title">Title</option>
        <option value="author">Author</option>
        <option value="added_at">Date Added</option>
        <option value="duration_seconds">Duration</option>
        <option value="published_year">Year</option>
      </select>

      <!-- Asc / Desc toggle -->
      <button
        type="button"
        class="rounded-md border border-slate-600 bg-slate-700 p-1.5 text-slate-300 hover:bg-slate-600 hover:text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
        :aria-label="sortDirection === 'asc' ? 'Sort ascending (click to sort descending)' : 'Sort descending (click to sort ascending)'"
        :title="sortDirection === 'asc' ? 'Ascending' : 'Descending'"
        @click="toggleSortDirection"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-4 w-4 transition-transform"
          :class="{ 'rotate-180': sortDirection === 'desc' }"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          stroke-width="2"
          aria-hidden="true"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M3 4h13M3 8h9m-9 4h6m4 0l4-4m0 0l4 4m-4-4v12" />
        </svg>
      </button>
    </div>

    <!-- Author filter -->
    <div v-if="authors.length > 0">
      <label for="filter-author" class="sr-only">Filter by author</label>
      <select
        id="filter-author"
        v-model="filterAuthor"
        class="rounded-md border border-slate-600 bg-slate-700 py-1.5 pl-2 pr-7 text-sm text-slate-100 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
        @change="emitFilter"
      >
        <option value="">All Authors</option>
        <option v-for="author in authors" :key="author" :value="author">{{ author }}</option>
      </select>
    </div>

    <!-- Series filter -->
    <div v-if="seriesList.length > 0">
      <label for="filter-series" class="sr-only">Filter by series</label>
      <select
        id="filter-series"
        v-model="filterSeries"
        class="rounded-md border border-slate-600 bg-slate-700 py-1.5 pl-2 pr-7 text-sm text-slate-100 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
        @change="emitFilter"
      >
        <option value="">All Series</option>
        <option v-for="s in seriesList" :key="s" :value="s">{{ s }}</option>
      </select>
    </div>

    <!-- Genre filter -->
    <div v-if="genres.length > 0">
      <label for="filter-genre" class="sr-only">Filter by genre</label>
      <select
        id="filter-genre"
        v-model="filterGenre"
        class="rounded-md border border-slate-600 bg-slate-700 py-1.5 pl-2 pr-7 text-sm text-slate-100 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
        @change="emitFilter"
      >
        <option value="">All Genres</option>
        <option v-for="genre in genres" :key="genre" :value="genre">{{ genre }}</option>
      </select>
    </div>

    <!-- Tag filter -->
    <div v-if="tags.length > 0">
      <label for="filter-tag" class="sr-only">Filter by tag</label>
      <select
        id="filter-tag"
        v-model="filterTag"
        class="rounded-md border border-slate-600 bg-slate-700 py-1.5 pl-2 pr-7 text-sm text-slate-100 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
        @change="emitFilter"
      >
        <option value="">All Tags</option>
        <option v-for="tag in tags" :key="tag" :value="tag">{{ tag }}</option>
      </select>
    </div>

    <!-- Progress filter -->
    <div>
      <label for="filter-progress" class="sr-only">Filter by progress</label>
      <select
        id="filter-progress"
        v-model="filterProgress"
        class="rounded-md border border-slate-600 bg-slate-700 py-1.5 pl-2 pr-7 text-sm text-slate-100 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
        @change="emitFilter"
      >
        <option value="">All Progress</option>
        <option value="in-progress">In Progress</option>
        <option value="finished">Finished</option>
        <option value="unfinished">Unfinished</option>
      </select>
    </div>

    <!-- Clear filters button (shown when any filter is active) -->
    <button
      v-if="hasActiveFilters"
      type="button"
      class="rounded-md border border-slate-600 bg-slate-700 px-2.5 py-1.5 text-xs text-slate-300 hover:bg-slate-600 hover:text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
      @click="clearFilters"
    >
      Clear filters
    </button>
  </div>
</template>

<script setup lang="ts">
import type { FilterOptions, SortOptions, SortField, SortDirection, ProgressFilter } from '~/composables/useLibraryItems'

const props = defineProps<{
  /** Available authors for the filter dropdown */
  authors?: string[]
  /** Available series for the filter dropdown */
  seriesList?: string[]
  /** Available genres for the filter dropdown */
  genres?: string[]
  /** Available tags for the filter dropdown */
  tags?: string[]
}>()

const emit = defineEmits<{
  (e: 'update:search', value: string): void
  (e: 'update:sort', value: SortOptions): void
  (e: 'update:filter', value: FilterOptions): void
}>()

// ─── Search (debounced 300 ms) ───────────────────────────────────────────────

const searchInput = ref('')
let searchDebounceTimer: ReturnType<typeof setTimeout> | null = null

watch(searchInput, (value) => {
  if (searchDebounceTimer) clearTimeout(searchDebounceTimer)
  searchDebounceTimer = setTimeout(() => {
    emit('update:search', value)
  }, 300)
})

// ─── Sort ────────────────────────────────────────────────────────────────────

const sortField = ref<SortField>('added_at')
const sortDirection = ref<SortDirection>('desc')

function emitSort() {
  emit('update:sort', { field: sortField.value, direction: sortDirection.value })
}

function toggleSortDirection() {
  sortDirection.value = sortDirection.value === 'asc' ? 'desc' : 'asc'
  emitSort()
}

// ─── Filters ─────────────────────────────────────────────────────────────────

const filterAuthor = ref('')
const filterSeries = ref('')
const filterGenre = ref('')
const filterTag = ref('')
const filterProgress = ref<ProgressFilter | ''>('')

function emitFilter() {
  const filter: FilterOptions = {}
  if (filterAuthor.value) filter.author = filterAuthor.value
  if (filterSeries.value) filter.series = filterSeries.value
  if (filterGenre.value) filter.genre = filterGenre.value
  if (filterTag.value) filter.tag = filterTag.value
  if (filterProgress.value) filter.progress = filterProgress.value as ProgressFilter
  emit('update:filter', filter)
}

const hasActiveFilters = computed(
  () =>
    !!filterAuthor.value ||
    !!filterSeries.value ||
    !!filterGenre.value ||
    !!filterTag.value ||
    !!filterProgress.value ||
    !!searchInput.value
)

function clearFilters() {
  filterAuthor.value = ''
  filterSeries.value = ''
  filterGenre.value = ''
  filterTag.value = ''
  filterProgress.value = ''
  searchInput.value = ''
  emit('update:filter', {})
  emit('update:search', '')
}

// ─── Prop defaults ───────────────────────────────────────────────────────────

const authors = computed(() => props.authors ?? [])
const seriesList = computed(() => props.seriesList ?? [])
const genres = computed(() => props.genres ?? [])
const tags = computed(() => props.tags ?? [])
</script>
