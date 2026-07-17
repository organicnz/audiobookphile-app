import { createClient } from "npm:@supabase/supabase-js@2.44.0";
import { corsHeaders } from "../../audiobookphile-backend/supabase/functions/_shared/cors.ts";
import { z } from "zod";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: corsHeaders,
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const openAiApiKey = Deno.env.get("OPENAI_API_KEY") ?? "";

    // Auth client with service role key to bypass RLS for DB but we will check user auth first
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const { data: { user }, error: userError } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", ""),
    );
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: corsHeaders,
      });
    }

    const SearchSchema = z.object({
      query: z.string().min(1).optional(),
      q: z.string().min(1).optional(),
    });

    let query = "";
    try {
      const body = await req.json();
      const parsed = SearchSchema.safeParse(body);
      if (parsed.success) {
        query = parsed.data.query || parsed.data.q || "";
      }
    } catch {
      const url = new URL(req.url);
      query = url.searchParams.get("q") || url.searchParams.get("query") || "";
    }

    if (!query) {
      return new Response(
        JSON.stringify({
          error: "Search query is required in body or query string",
        }),
        { status: 400, headers: corsHeaders },
      );
    }

    if (!openAiApiKey) {
      return new Response(
        JSON.stringify({
          error: "OPENAI_API_KEY is not configured on the server",
        }),
        { status: 500, headers: corsHeaders },
      );
    }

    // 1. Generate embedding for the search query using OpenAI
    const res = await fetch("https://api.openai.com/v1/embeddings", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openAiApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        input: query,
        model: "text-embedding-3-small",
      }),
    });

    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Failed to fetch from OpenAI API: ${errText}`);
    }

    const data = await res.json();
    if (!data.data || data.data.length === 0 || !data.data[0].embedding) {
      throw new Error("No embedding returned from OpenAI.");
    }

    const queryEmbedding = data.data[0].embedding;

    // 2. Perform vector search in Supabase using the RPC
    const { data: matches, error: matchError } = await supabase.rpc(
      "search_library_items_by_embedding",
      {
        query_embedding: queryEmbedding,
        match_threshold: 0.1, // low threshold to allow fuzzy matches
        match_count: 10,
      },
    );

    if (matchError) {
      throw new Error(`Failed to execute vector search: ${matchError.message}`);
    }

    if (!matches || matches.length === 0) {
      return new Response(JSON.stringify({ results: [] }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const ids = matches.map((m: any) => m.id);

    // 3. Fetch full items
    const { data: items, error: itemsError } = await supabase
      .from("library_items")
      .select("*, media:media(*)")
      .in("id", ids);

    if (itemsError) {
      throw new Error(`Failed to fetch library items: ${itemsError.message}`);
    }

    // Sort items based on the similarity rank
    const sortedItems = items.sort((a, b) =>
      ids.indexOf(a.id) - ids.indexOf(b.id)
    );

    return new Response(JSON.stringify({ results: sortedItems }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e: unknown) {
    const err = e as Error;
    console.error("Semantic search error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
