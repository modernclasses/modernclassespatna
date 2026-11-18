import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

serve(async (req) => {
  // Authoritative execution: only permitted for internal cron or service_role callers
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const packageName = Deno.env.get('ANDROID_PACKAGE_NAME');
    const serviceAccountJson = Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), { status: 401 });
    }
    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!supabaseServiceKey || token !== supabaseServiceKey) {
      return new Response(JSON.stringify({ error: 'Unauthorized: Service role key required' }), { status: 403 });
    }

    if (!packageName || !serviceAccountJson) {
       return new Response(JSON.stringify({ error: 'Missing config' }), { status: 500 });
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // Fetch all pending acknowledgements
    const { data: pendingPurchases, error: dbError } = await adminClient
      .from('purchases')
      .select('store_product_id, purchase_token')
      .eq('status', 'purchased')
      .eq('acknowledgement_state', 'acknowledgement_pending');

    if (dbError) throw dbError;

    if (!pendingPurchases || pendingPurchases.length === 0) {
      return new Response(JSON.stringify({ message: 'No pending acknowledgements' }), { status: 200 });
    }

    const googleAccessToken = await getGoogleAccessToken(serviceAccountJson);
    const results = [];

    for (const purchase of pendingPurchases) {
      const ackUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/products/${encodeURIComponent(purchase.store_product_id)}/tokens/${encodeURIComponent(purchase.purchase_token)}:acknowledge`;
      
      const ackResponse = await fetch(ackUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${googleAccessToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
      });

      if (ackResponse.ok) {
        await adminClient.rpc('update_purchase_acknowledgement', {
          p_purchase_token: purchase.purchase_token,
          p_new_state: 'acknowledged'
        });
        results.push({ token: purchase.purchase_token, status: 'success' });
      } else {
        const errorText = await ackResponse.text();
        // If it's already acknowledged or 4xx, we might need to handle it or mark it
        results.push({ token: purchase.purchase_token, status: 'failed', error: errorText });
      }
    }

    return new Response(JSON.stringify({ processed: pendingPurchases.length, results }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });

  } catch (err: any) {
    console.error(err);
    return new Response(JSON.stringify({ error: 'Internal Server Error', message: err.message }), { status: 500 });
  }
});

async function getGoogleAccessToken(serviceAccountJsonStr: string): Promise<string> {
  const sa = JSON.parse(serviceAccountJsonStr);
  const pem = sa.private_key;
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
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };

  const b64 = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const unsignedToken = `${b64(header)}.${b64(claimSet)}`;

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
  if (!res.ok) throw new Error(`Google Auth Failed: ${JSON.stringify(data)}`);
  return data.access_token;
}
