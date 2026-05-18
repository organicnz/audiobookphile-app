import type { Library } from '~/types'

export interface UseLibrary {
  fetchLibraries(): Promise<{ data: Library[] | null; error: Error | null }>
  createLibrary(name: string, mediaType: 'audiobook' | 'podcast'): Promise<{ data: Library | null; error: Error | null }>
  updateLibrary(id: string, name: string): Promise<{ data: Library | null; error: Error | null }>
  deleteLibrary(id: string): Promise<{ error: Error | null }>
}

/**
 * Library composable — wraps Supabase queries for the `libraries` table.
 * All queries rely on RLS; no manual user_id filter is needed.
 *
 * Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6
 */
export const useLibrary = (): UseLibrary => {
  const supabase = useSupabaseClient()

  /**
   * Fetch all libraries accessible to the authenticated user.
   * RLS ensures only the user's own libraries are returned.
   * Requirement 2.3
   */
  async function fetchLibraries(): Promise<{ data: Library[] | null; error: Error | null }> {
    const { data, error } = await supabase.from('libraries').select('*').order('created_at', { ascending: true })

    return {
      data: data as Library[] | null,
      error: error as Error | null
    }
  }

  /**
   * Create a new library for the authenticated user.
   * The owner_user_id is set by the RLS INSERT policy (auth.uid()).
   * Requirement 2.2
   */
  async function createLibrary(name: string, mediaType: 'audiobook' | 'podcast'): Promise<{ data: Library | null; error: Error | null }> {
    const { data, error } = await supabase.from('libraries').insert({ name, media_type: mediaType }).select().single()

    return {
      data: data as Library | null,
      error: error as Error | null
    }
  }

  /**
   * Update the name of an existing library.
   * RLS ensures only the owner can update.
   * Requirement 2.4
   */
  async function updateLibrary(id: string, name: string): Promise<{ data: Library | null; error: Error | null }> {
    const { data, error } = await supabase.from('libraries').update({ name, updated_at: new Date().toISOString() }).eq('id', id).select().single()

    return {
      data: data as Library | null,
      error: error as Error | null
    }
  }

  /**
   * Delete a library by id.
   * Cascade deletes of library_items, media_progress, bookmarks, etc.
   * are handled by the database foreign key constraints.
   * RLS ensures only the owner can delete.
   * Requirement 2.5
   */
  async function deleteLibrary(id: string): Promise<{ error: Error | null }> {
    const { error } = await supabase.from('libraries').delete().eq('id', id)

    return { error: error as Error | null }
  }

  return {
    fetchLibraries,
    createLibrary,
    updateLibrary,
    deleteLibrary
  }
}
