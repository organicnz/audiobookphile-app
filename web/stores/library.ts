import { defineStore } from 'pinia'
import type { Library } from '~/types'

export interface LibraryState {
  libraries: Library[]
  currentLibraryId: string | null
  loading: boolean
}

export const useLibraryStore = defineStore('library', {
  state: (): LibraryState => ({
    libraries: [],
    currentLibraryId: null,
    loading: false
  }),

  getters: {
    /**
     * Returns the Library object for the currently selected library id,
     * or null if no library is selected or the id doesn't match any library.
     */
    currentLibrary: (state): Library | null => {
      if (!state.currentLibraryId) return null
      return state.libraries.find((lib) => lib.id === state.currentLibraryId) ?? null
    }
  },

  actions: {
    /**
     * Replace the full list of libraries (e.g. after a fetch).
     */
    setLibraries(libraries: Library[]) {
      this.libraries = libraries
    },

    /**
     * Append a newly created library to the list.
     */
    addLibrary(library: Library) {
      this.libraries.push(library)
    },

    /**
     * Update an existing library in the list by id.
     */
    updateLibrary(updated: Library) {
      const index = this.libraries.findIndex((lib) => lib.id === updated.id)
      if (index !== -1) {
        this.libraries[index] = updated
      }
    },

    /**
     * Remove a library from the list by id.
     * If the removed library was the current one, clear the selection.
     */
    removeLibrary(id: string) {
      this.libraries = this.libraries.filter((lib) => lib.id !== id)
      if (this.currentLibraryId === id) {
        this.currentLibraryId = this.libraries[0]?.id ?? null
      }
    },

    /**
     * Set the currently active library by id.
     */
    setCurrentLibrary(id: string | null) {
      this.currentLibraryId = id
    },

    /**
     * Set the loading state.
     */
    setLoading(loading: boolean) {
      this.loading = loading
    }
  }
})
