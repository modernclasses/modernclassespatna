import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import { evaluateDisplayName } from "./moderation.ts";

const allowedOrigins = [
  'https://app.modernclassespatna.com',
  'http://localhost:3000',
  'capacitor://localhost',
  'http://localhost'
];

function getCorsHeaders(req: Request) {
  const origin = req.headers.get('origin');
  const allowOrigin = (origin && allowedOrigins.includes(origin)) ? origin : (origin ? 'null' : '*');
  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };
}

export async function handler(req: Request) {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: getCorsHeaders(req),
    });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

    const authHeader = req.headers.get('Authorization');

    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        {
          status: 401,
          headers: {
            ...getCorsHeaders(req),
            'Content-Type': 'application/json',
          },
        },
      );
    }

    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    if (!match) {
      return new Response(
        JSON.stringify({ error: 'Invalid authorization format' }),
        {
          status: 401,
          headers: {
            ...getCorsHeaders(req),
            'Content-Type': 'application/json',
          },
        },
      );
    }

    const jwt = match[1].trim();
    if (!jwt) {
      return new Response(
        JSON.stringify({ error: 'Invalid authorization format' }),
        {
          status: 401,
          headers: {
            ...getCorsHeaders(req),
            'Content-Type': 'application/json',
          },
        },
      );
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const {
      data: { user },
      error: authError,
    } = await userClient.auth.getUser(jwt);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        {
          status: 401,
          headers: {
            ...getCorsHeaders(req),
            'Content-Type': 'application/json',
          },
        },
      );
    }

    const { new_name } = await req.json();

    if (!new_name || typeof new_name !== 'string' || new_name.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: 'Display name cannot be empty' }),
        {
          status: 400,
          headers: {
            ...getCorsHeaders(req),
            'Content-Type': 'application/json',
          },
        },
      );
    }

    const trimmedName = new_name.trim();

    if (trimmedName.length > 15) {
      return new Response(
        JSON.stringify({ error: 'Display name must be 15 characters or fewer' }),
        {
          status: 400,
          headers: {
            ...getCorsHeaders(req),
            'Content-Type': 'application/json',
          },
        },
      );
    }

    const result = evaluateDisplayName(trimmedName);

    if (result.action === 'BLOCK') {
      console.warn(
        JSON.stringify({
          event: 'moderation_rejection',
          userId: user.id,
          layer: 'lexical',
          category: 'prohibited_term',
        }),
      );
      return new Response(
        JSON.stringify({ error: 'Display name rejected due to prohibited lexical term' }),
        {
          status: 400,
          headers: {
            ...getCorsHeaders(req),
            'Content-Type': 'application/json',
          },
        },
      );
    }

    if (result.action === 'REVIEW') {
      console.warn(
        JSON.stringify({
          event: 'moderation_review_flagged',
          userId: user.id,
          layer: 'lexical',
          category: 'context_required',
          matchedTerm: result.matchedTerm
        }),
      );
      // We block the update because there is no human review queue currently implemented.
      return new Response(
        JSON.stringify({ error: 'Display name flagged for review. Manual moderation is currently required.' }),
        {
          status: 400,
          headers: {
            ...getCorsHeaders(req),
            'Content-Type': 'application/json',
          },
        },
      );
    }

    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!serviceRoleKey) {
      return new Response(JSON.stringify({ error: 'Server misconfiguration' }), { status: 500 });
    }

    const serviceClient = createClient(supabaseUrl, serviceRoleKey);

    const { data, error: rpcError } = await serviceClient.rpc('set_student_display_name_once', {
      target_user_id: user.id,
      new_name: trimmedName,
    });

    if (rpcError) {
      console.error('RPC Error:', rpcError.message);
      return new Response(
        JSON.stringify({ error: rpcError.message || 'Failed to update profile' }),
        {
          status: 400,
          headers: {
            ...getCorsHeaders(req),
            'Content-Type': 'application/json',
          },
        },
      );
    }

    if (Array.isArray(data) && data.length > 0) {
      return new Response(JSON.stringify(data[0]), {
        headers: {
          ...getCorsHeaders(req),
          'Content-Type': 'application/json',
        },
      });
    }

    return new Response(
      JSON.stringify({ error: 'Unexpected empty response from database' }),
      {
        status: 500,
        headers: {
          ...getCorsHeaders(req),
          'Content-Type': 'application/json',
        },
      },
    );
  } catch (err) {
    console.error('Internal Error:', err instanceof Error ? err.message : err);
    return new Response(
      JSON.stringify({ error: 'Internal Server Error' }),
      {
        status: 500,
        headers: {
          ...getCorsHeaders(req),
          'Content-Type': 'application/json',
        },
      },
    );
  }
}

if (import.meta.main) {
  serve(handler);
}
