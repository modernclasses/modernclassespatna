import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Generate Google OAuth2 Access Token for FCM HTTP v1 using Web Crypto
async function getGoogleAccessToken(serviceAccount: { client_email: string; private_key: string }): Promise<string> {
  const pem = serviceAccount.private_key;
  const pemHeader = '-----BEGIN PRIVATE KEY-----';
  const pemFooter = '-----END PRIVATE KEY-----';
  const pemContents = pem.substring(
    pem.indexOf(pemHeader) + pemHeader.length,
    pem.indexOf(pemFooter)
  ).replace(/\s/g, '');

  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };

  const base64UrlEncode = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  const unsignedToken = `${base64UrlEncode(header)}.${base64UrlEncode(claimSet)}`;

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const signedToken = `${unsignedToken}.${btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: signedToken,
    }),
  });

  const data = await res.json();
  if (!res.ok) {
    throw new Error(`Google OAuth error: ${JSON.stringify(data)}`);
  }
  return data.access_token;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

    // 1. Authoritative Authentication & Role Verification Guard
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized: Missing Authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    let isAuthorized = false;

    // A. Check for direct service_role match (Database Webhook trigger passes service_role key)
    if (supabaseServiceKey && token === supabaseServiceKey) {
      isAuthorized = true;
    } else {
      // B. Cryptographically verify JWT session and check if caller is an administrator
      const userClient = createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: authHeader } },
        auth: { persistSession: false },
      });

      const { data: { user }, error: userError } = await userClient.auth.getUser(token);
      if (!userError && user) {
        const adminClient = createClient(supabaseUrl, supabaseServiceKey);
        const { data: profile } = await adminClient
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

        if (profile?.role === 'admin') {
          isAuthorized = true;
        }
      }
    }

    if (!isAuthorized) {
      return new Response(
        JSON.stringify({ error: 'Forbidden: Admin or service_role authorization required' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    let fcmServiceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT_KEY') ?? '';
    if (!fcmServiceAccountJson) {
      try {
        fcmServiceAccountJson = await Deno.readTextFile(new URL('./service_account.json', import.meta.url));
      } catch (_) {}
    }

    if (!fcmServiceAccountJson) {
      return new Response(
        JSON.stringify({
          error: 'FCM_SERVICE_ACCOUNT_KEY is not configured in Supabase Edge Function Secrets or service_account.json.',
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const serviceAccount = JSON.parse(fcmServiceAccountJson);
    const projectId = serviceAccount.project_id;

    // Payload from Webhook (record) or direct invocation
    const body = await req.json();
    const record = body.record || body;

    const {
      title,
      message,
      type = 'announcement',
      target_batch_id = null,
      target_role = null,
    } = record;

    if (!title || !message) {
      return new Response(
        JSON.stringify({ error: 'Title and message are required in announcement payload.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Resolve Target User IDs
    let targetUserIds: string[] = [];

    if (target_batch_id) {
      // Find students enrolled in batch
      const { data: enrollments } = await supabase
        .from('enrollments')
        .select('student_id')
        .eq('batch_id', target_batch_id)
        .eq('is_active', true);

      if (enrollments && enrollments.length > 0) {
        targetUserIds.push(...enrollments.map((e: { student_id: string }) => e.student_id));
      }

      // Also find assigned teacher
      const { data: batch } = await supabase
        .from('batches')
        .select('assigned_teacher_id')
        .eq('id', target_batch_id)
        .maybeSingle();

      if (batch?.assigned_teacher_id) {
        targetUserIds.push(batch.assigned_teacher_id);
      }
    } else if (target_role) {
      const { data: profiles } = await supabase
        .from('profiles')
        .select('id')
        .eq('role', target_role)
        .eq('is_active', true);

      if (profiles && profiles.length > 0) {
        targetUserIds.push(...profiles.map((p: { id: string }) => p.id));
      }
    } else {
      // Broadcast to all active users
      const { data: profiles } = await supabase
        .from('profiles')
        .select('id')
        .eq('is_active', true);

      if (profiles && profiles.length > 0) {
        targetUserIds.push(...profiles.map((p: { id: string }) => p.id));
      }
    }

    // Deduplicate user IDs
    targetUserIds = Array.from(new Set(targetUserIds));

    if (targetUserIds.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No target users found for this notification.' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 2. Query FCM Tokens for Target Users
    const { data: tokens, error: tokenError } = await supabase
      .from('user_device_tokens')
      .select('fcm_token, user_id')
      .in('user_id', targetUserIds);

    if (tokenError) {
      throw tokenError;
    }

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No active device tokens found for target recipients.' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 3. Acquire Google OAuth2 token
    const accessToken = await getGoogleAccessToken(serviceAccount);

    // 4. Send FCM Push Notification to Each Token
    const results = [];
    const invalidTokens: string[] = [];

    for (const item of tokens) {
      const fcmPayload = {
        message: {
          token: item.fcm_token,
          notification: {
            title: title,
            body: message,
          },
          data: {
            type: String(type),
            target_batch_id: String(target_batch_id ?? ''),
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          android: {
            priority: 'high',
            notification: {
              channel_id: 'modern_classes_alerts',
              sound: 'default',
              default_vibrate_timings: true,
              default_light_settings: true,
              notification_priority: 'PRIORITY_MAX',
              visibility: 'PUBLIC',
            },
          },
        },
      };

      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(fcmPayload),
        }
      );

      const resData = await res.json();
      if (!res.ok) {
        // If token has expired or app was uninstalled, clean up token
        if (
          resData.error?.status === 'NOT_FOUND' ||
          resData.error?.details?.some((d: { errorCode?: string }) => d.errorCode === 'UNREGISTERED')
        ) {
          invalidTokens.push(item.fcm_token);
        }
      }
      results.push({ token: item.fcm_token, status: res.status });
    }

    // Clean up expired tokens
    if (invalidTokens.length > 0) {
      await supabase.from('user_device_tokens').delete().in('fcm_token', invalidTokens);
    }

    return new Response(
      JSON.stringify({
        success: true,
        totalRecipients: tokens.length,
        results,
        cleanedTokens: invalidTokens.length,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message || String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
