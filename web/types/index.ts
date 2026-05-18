export interface Library {
  id: string
  owner_user_id: string
  name: string
  media_type: 'audiobook' | 'podcast'
  created_at: string
  updated_at: string
}

export interface LibraryItem {
  id: string
  library_id: string
  title: string
  author: string | null
  narrator: string | null
  series: string | null
  series_sequence: string | null
  genres: string[]
  tags: string[]
  description: string | null
  cover_image_path: string | null
  duration_seconds: number | null
  published_year: number | null
  added_at: string
  updated_at: string
}

export interface MediaProgress {
  id: string
  user_id: string
  library_item_id: string
  episode_id: string | null
  current_time: number
  duration: number | null
  progress: number
  is_finished: boolean
  ebook_location: string | null
  ebook_progress: number | null
  last_update: string
}

export interface MediaFile {
  id: string
  library_item_id: string
  storage_path: string
  filename: string
  mime_type: string
  size_bytes: number | null
  track_index: number
  duration_seconds: number | null
  created_at: string
}

export interface Bookmark {
  id: string
  user_id: string
  library_item_id: string
  time_seconds: number
  title: string | null
  created_at: string
}

export interface UserPreferences {
  user_id: string
  playback_rate: number
  jump_forward_seconds: number
  jump_backward_seconds: number
  theme: 'light' | 'dark' | 'system'
  order_by: string
  order_desc: boolean
  filter_by: string | null
  collapse_series: boolean
  updated_at: string
}
