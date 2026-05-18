import { createClient } from '@supabase/supabase-js'

export default ({ app }, inject) => {
  // Use environment variables for the Supabase configuration
  const supabaseUrl = process.env.NUXT_ENV_SUPABASE_URL || 'YOUR_SUPABASE_URL'
  const supabaseKey = process.env.NUXT_ENV_SUPABASE_ANON_KEY || 'YOUR_SUPABASE_ANON_KEY'

  if (supabaseUrl === 'YOUR_SUPABASE_URL') {
    console.warn('[Supabase] Missing NUXT_ENV_SUPABASE_URL! Please set it before building the app.')
  }

  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: {
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false
    }
  })

  inject('supabase', supabase)
}
