import type { LibraryItem } from '~/types'

// ─── Option types ────────────────────────────────────────────────────────────

export type SortField = 'title' | 'author' | 'added_at' | 'duration_seconds' | 'published_year'
export type SortDirection = 'asc' | 'desc'
export type ProgressFilter = 'finished' | 'unfinished' | 'in-progress'

export interface FilterOptions {
  author?: string
  series?: string
  genre?: string
  tag?: string
  progress?: ProgressFilter
}

export interface SortOptions {
  field: SortField
  direction: SortDirection
}

export interface FetchItemsOptions {
  page?: number
  pageSize?: number
  filter?: FilterOptions
  sort?: SortOptions
  search?: string
}

export interface FetchItemsResult {
  items: LibraryItem[]
  total: number
  page: number
  pageSize: number
}

// ─── Composable ──────────────────────────────────────────────────────────────

export interface UseLibraryItems {
  fetchItems(libraryId: string, options?: FetchItemsOptions): Promise<FetchItemsResult>
  createItem(libraryId: string, data: Partial<LibraryItem>): Promise<{ data: LibraryItem | null; error: Error | null }>
  updateItem(id: string, data: Partial<LibraryItem>): Promise<{ data: LibraryItem | null; error: Error | null }>
  deleteItem(id: string): Promise<{ error: Error | null }>
}

/**
 * Library items composable — wraps Supabase queries for the `library_items` table.
 * Supports pagination, filtering, sorting, and full-text search.
 *
 * Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7
 */
export const useLibraryItems = (): UseLibraryItems => {
  const supabase = useSupabaseClient()

  /**
   * Fetch paginated library items with optional filter, sort, and search.
   *
   * - pageSize is clamped to [10, 100], defaulting to 20.
   * - Filter by author/series uses exact match (eq).
   * - Filter by genre/tag uses array containment (cs).
   * - Filter by progress status joins media_progress.
   * - Search uses ilike across title, author, narrator, series, description.
   * - Sort defaults to added_at desc.
   *
   * Requirements: 3.3, 3.4, 3.5, 3.6
   */
  async function fetchItems(libraryId: string, options: FetchItemsOptions = {}): Promise<FetchItemsResult> {
    const page = Math.max(1, options.page ?? 1)
    const pageSize = Math.min(100, Math.max(10, options.pageSize ?? 20))
    const from = (page - 1) * pageSize
    const to = from + pageSize - 1

    const sort = options.sort ?? { field: 'added_at', direction: 'desc' }
    const filter = options.filter ?? {}
    const search = options.search?.trim() ?? ''

    // Build the base query
    let query = supabase.from('library_items').select('*', { count: 'exact' }).eq('library_id', libraryId)

    // ── Filters ──────────────────────────────────────────────────────────────

    if (filter.author) {
      query = query.eq('author', filter.author)
    }

    if (filter.series) {
      query = query.eq('series', filter.series)
    }

    if (filter.genre) {
      // genres is a text[] column; cs = "contains" (array contains element)
      query = query.contains('genres', [filter.genre])
    }

    if (filter.tag) {
      query = query.contains('tags', [filter.tag])
    }

    // Progress filter: join with media_progress to check is_finished / current_time
    if (filter.progress) {
      if (filter.progress === 'finished') {
        // Items where the user has a finished progress record
        query = query.in(
          'id',
          // Sub-select via RPC is not available in PostgREST directly;
          // use a nested select string that PostgREST supports
          (supabase.from('media_progress').select('library_item_id').eq('is_finished', true) as unknown as { url: string }).url ? [] : []
        )
        // PostgREST doesn't support correlated sub-selects in the JS client.
        // We use a workaround: fetch finished item ids first, then filter.
        // This is handled below after the main query.
      }
    }

    // ── Search ───────────────────────────────────────────────────────────────

    if (search) {
      // ilike across multiple columns using PostgREST `or` filter
      const term = `%${search}%`
      query = query.or(`title.ilike.${term},author.ilike.${term},narrator.ilike.${term},series.ilike.${term},description.ilike.${term}`)
    }

    // ── Sort ─────────────────────────────────────────────────────────────────

    query = query.order(sort.field, { ascending: sort.direction === 'asc' })

    // ── Pagination ───────────────────────────────────────────────────────────

    query = query.range(from, to)

    // ── Execute ──────────────────────────────────────────────────────────────

    let { data, error, count } = await query

    if (error) {
      console.error('[useLibraryItems] fetchItems error:', error)
      return { items: [], total: 0, page, pageSize }
    }

    let items = (data as LibraryItem[]) ?? []

    // ── Progress filter post-processing ──────────────────────────────────────
    // Because PostgREST JS client doesn't support correlated sub-selects,
    // we apply progress-based filters client-side after fetching the page.
    if (filter.progress && items.length > 0) {
      const itemIds = items.map((item) => item.id)

      const { data: progressData } = await supabase.from('media_progress').select('library_item_id, is_finished, current_time, duration').in('library_item_id', itemIds)

      const progressMap = new Map((progressData ?? []).map((p: { library_item_id: string; is_finished: boolean; current_time: number; duration: number | null }) => [p.library_item_id, p]))

      if (filter.progress === 'finished') {
        items = items.filter((item) => progressMap.get(item.id)?.is_finished === true)
      } else if (filter.progress === 'unfinished') {
        items = items.filter((item) => {
          const p = progressMap.get(item.id)
          return !p || p.is_finished === false
        })
      } else if (filter.progress === 'in-progress') {
        items = items.filter((item) => {
          const p = progressMap.get(item.id)
          return p && p.is_finished === false && p.current_time > 0
        })
      }
    }

    return {
      items,
      total: count ?? 0,
      page,
      pageSize
    }
  }

  /**
   * Create a new library item.
   * RLS validates that the library_id belongs to the authenticated user.
   * Requirement 3.2
   */
  async function createItem(libraryId: string, data: Partial<LibraryItem>): Promise<{ data: LibraryItem | null; error: Error | null }> {
    const { data: created, error } = await supabase
      .from('library_items')
      .insert({ ...data, library_id: libraryId })
      .select()
      .single()

    return {
      data: created as LibraryItem | null,
      error: error as Error | null
    }
  }

  /**
   * Update an existing library item by id.
   * RLS ensures only items in the user's libraries can be updated.
   */
  async function updateItem(id: string, data: Partial<LibraryItem>): Promise<{ data: LibraryItem | null; error: Error | null }> {
    const { data: updated, error } = await supabase
      .from('library_items')
      .update({ ...data, updated_at: new Date().toISOString() })
      .eq('id', id)
      .select()
      .single()

    return {
      data: updated as LibraryItem | null,
      error: error as Error | null
    }
  }

  /**
   * Delete a library item and clean up associated storage files.
   * DB cascade handles media_progress, bookmarks, playlist_items.
   * Storage cleanup is attempted for the item's media files.
   * Requirement 3.7
   */
  async function deleteItem(id: string): Promise<{ error: Error | null }> {
    // Fetch associated media files before deleting the item record
    const { data: mediaFiles } = await supabase.from('media_files').select('storage_path').eq('library_item_id', id)

    // Delete the item record (DB cascade handles child rows)
    const { error } = await supabase.from('library_items').delete().eq('id', id)

    if (error) {
      return { error: error as Error }
    }

    // Clean up storage files after the DB record is gone
    if (mediaFiles && mediaFiles.length > 0) {
      const paths = (mediaFiles as { storage_path: string }[]).map((f) => f.storage_path)
      const { error: storageError } = await supabase.storage.from('media').remove(paths)

      if (storageError) {
        // Log but don't fail — the DB record is already deleted
        console.warn('[useLibraryItems] Storage cleanup error:', storageError)
      }
    }

    return { error: null }
  }

  return {
    fetchItems,
    createItem,
    updateItem,
    deleteItem
  }
}
