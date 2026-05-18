import EventEmitter from 'events'

class ServerSocket extends EventEmitter {
  constructor(store, supabase) {
    super()

    this.$store = store
    this.$supabase = supabase
    this.channel = null
    this.connected = false
    this.serverAddress = null
    this.isAuthenticated = false
  }

  $on(evt, callback) {
    this.on(evt, callback)
  }

  $off(evt, callback) {
    this.off(evt, callback)
  }

  connect(serverAddress, token) {
    this.serverAddress = serverAddress
    if (!this.$supabase) {
      console.error('[SOCKET/SUPABASE] Supabase client not initialized')
      return
    }

    console.log(`[SOCKET/SUPABASE] Connecting via Supabase Realtime...`)
    
    // We create a channel to listen to media_progress updates for real-time sync
    this.channel = this.$supabase.channel('public:media_progress')

    this.channel
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'media_progress' },
        (payload) => {
          this.onUserItemProgressUpdated(payload.new)
        }
      )
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'media_progress' },
        (payload) => {
          this.onUserItemProgressUpdated(payload.new)
        }
      )
      .subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          this.onConnect()
        } else if (status === 'CLOSED' || status === 'CHANNEL_ERROR') {
          this.onDisconnect(status)
        }
      })
  }

  logout() {
    if (this.channel) {
      this.$supabase.removeChannel(this.channel)
      this.channel = null
    }
    this.connected = false
    this.isAuthenticated = false
  }

  sendAuthenticate() {
    // Supabase handles auth automatically via JWT in headers.
    // We just emit init to signify we are ready.
    this.onInit({ message: 'Supabase Realtime Ready' })
  }

  onConnect() {
    console.log('[SOCKET/SUPABASE] Connected to Supabase Realtime')
    this.connected = true
    this.$store.commit('setSocketConnected', true)
    this.emit('connection-update', true)
    this.sendAuthenticate()
  }

  onDisconnect(reason) {
    console.log('[SOCKET/SUPABASE] Disconnected: ' + reason)
    this.connected = false
    this.$store.commit('setSocketConnected', false)
    this.emit('connection-update', false)
  }

  onInit(data) {
    console.log('[SOCKET/SUPABASE] Initial socket data received', data)
    this.emit('initialized', true)
    this.isAuthenticated = true
  }

  onUserItemProgressUpdated(payload) {
    console.log('[SOCKET/SUPABASE] User Item Progress Updated', payload)
    
    // Map Supabase payload to the format expected by Vuex
    // Supabase media_progress table: id, user_id, library_item_id, episode_id, duration, progress, currentTime, isFinished, etc.
    const mappedPayload = {
      id: payload.id,
      libraryItemId: payload.library_item_id,
      episodeId: payload.episode_id,
      duration: payload.duration,
      progress: payload.progress,
      currentTime: payload.currentTime || payload.current_time,
      isFinished: payload.isFinished || payload.is_finished,
      hideFromContinueListening: payload.hide_from_continue_listening,
      lastUpdate: new Date(payload.updated_at).getTime(),
      startedAt: new Date(payload.created_at).getTime(),
    }

    this.$store.commit('user/updateUserMediaProgress', mappedPayload)
    this.emit('user_media_progress_updated', { data: mappedPayload })
  }

  onPlaylistAdded() {
    if (!this.$store.state.libraries.numUserPlaylists) {
      this.$store.commit('libraries/setNumUserPlaylists', 1)
    }
  }
}

export default ({ app, store }, inject) => {
  inject('socket', new ServerSocket(store, app.$supabase))
}
