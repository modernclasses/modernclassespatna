import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { purchaseToken, batchId } = await req.json();

    if (!purchaseToken) {
      return new Response(JSON.stringify({ error: 'purchaseToken is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 1. Authenticate user
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false }
    });
    
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await userClient.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized', details: authError }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const studentId = user.id;

    // 2. ENVIRONMENT & BILLING MODE GUARD
    const environment = Deno.env.get('ENVIRONMENT') ?? Deno.env.get('APP_ENV') ?? 'production';
    const allowMock = Deno.env.get('USE_MOCK_BILLING') === 'true';
    // Strictly forbid mock billing in production
    const isMockAllowed = allowMock && (environment === 'development' || environment === 'test' || environment === 'local');
    const isMockPurchase = purchaseToken.startsWith('mockpurchase:');
    const useMockBilling = isMockAllowed && isMockPurchase;

    let productId, purchaseStateGoogle, ackStateGoogle, orderId, purchaseTimeMillis;
    let googleAccessToken = '';
    const packageName = Deno.env.get('ANDROID_PACKAGE_NAME');

    if (purchaseToken.startsWith('mockpurchase:')) {
      if (!isMockAllowed) {
        return new Response(
          JSON.stringify({ 
            error: 'Mock billing is disabled in this environment. Genuine Google Play purchase verification is required.',
            code: 'MOCK_BILLING_FORBIDDEN'
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      console.log("SANDBOX MODE ACTIVE: Bypassing Google Play Verification for test token:", purchaseToken);
      
      // Parse deterministic mock token format: mockpurchase:<productId>:<timestamp>
      const mockTokenParts = purchaseToken.split(':');
      if (mockTokenParts.length !== 3 || mockTokenParts[0] !== 'mockpurchase') {
        return new Response(JSON.stringify({ error: 'Invalid mock token format. Must be mockpurchase:<productId>:<timestamp>.' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      productId = mockTokenParts[1];
      
      if (!productId || productId.trim() === '') {
        return new Response(JSON.stringify({ error: 'Mock product ID cannot be empty.' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      purchaseStateGoogle = 'PURCHASED';
      ackStateGoogle = 'NOT_ACKNOWLEDGED';
      orderId = `MOCK_ORDER_${Date.now()}`;
      purchaseTimeMillis = Date.now().toString();
    } else {
      // PRODUCTION GOOGLE PLAY API LOGIC
      const serviceAccountJson = Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');
      
      if (!packageName || !serviceAccountJson) {
         console.error("Missing Google Play configuration in Edge Function environment variables.");
         return new Response(
           JSON.stringify({ 
             error: 'In-app purchase verification service is currently unavailable. Please contact institute support.',
             code: 'BILLING_GATEWAY_UNAVAILABLE'
           }), 
           { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
         );
      }

      googleAccessToken = await getGoogleAccessToken(serviceAccountJson);
      const productsv2VerifyUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/productsv2/tokens/${encodeURIComponent(purchaseToken)}`;

      const googleResponse = await fetch(productsv2VerifyUrl, {
        headers: {
          'Authorization': `Bearer ${googleAccessToken}`,
          'Accept': 'application/json'
        }
      });

      if (!googleResponse.ok) {
         return new Response(JSON.stringify({ error: 'Google Play verification failed', details: await googleResponse.text() }), {
           status: 400,
           headers: { ...corsHeaders, 'Content-Type': 'application/json' },
         });
      }

      const playData = await googleResponse.json();
      
      productId = playData.productLineItem?.[0]?.productId ?? playData.productId; 
      purchaseStateGoogle = playData.purchaseState; 
      ackStateGoogle = playData.acknowledgementState; 
      orderId = playData.orderId;
      purchaseTimeMillis = playData.purchaseTimeMillis;
    }
    
    // Canonicalize purchase state
    let mappedStatus = 'pending';
    if (purchaseStateGoogle === 'PURCHASED' || purchaseStateGoogle === 0) mappedStatus = 'purchased';
    else if (purchaseStateGoogle === 'CANCELED' || purchaseStateGoogle === 1) mappedStatus = 'canceled';
    
    let mappedAckState = 'not_acknowledged';
    if (ackStateGoogle === 'ACKNOWLEDGED' || ackStateGoogle === 1) mappedAckState = 'acknowledged';

    if (mappedStatus !== 'purchased') {
      return new Response(
        JSON.stringify({
          error: `Payment not completed. Google Play purchase state is '${purchaseStateGoogle}'.`,
          code: 'PURCHASE_NOT_CONFIRMED'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 3. Resolve Batch and Atomic Grant via RPC
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // Verify batch is active and product matches
    if (batchId) {
      const { data: batch, error: batchError } = await adminClient
        .from('batches')
        .select('id, course_id, play_product_id, is_active')
        .eq('id', batchId)
        .maybeSingle();

      if (batchError || !batch) {
        return new Response(
          JSON.stringify({ error: 'Selected batch was not found.' }),
          { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      if (!batch.is_active) {
        return new Response(
          JSON.stringify({ error: 'Selected batch is not active for enrollment.' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      if (batch.play_product_id && batch.play_product_id !== productId) {
        return new Response(
          JSON.stringify({ 
            error: `Product mismatch: Verified product (${productId}) does not match batch product (${batch.play_product_id}).` 
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    const { data: purchaseId, error: rpcError } = await adminClient.rpc('record_verified_purchase_and_enroll', {
      p_student_id: studentId,
      p_store_product_id: productId,
      p_purchase_token: purchaseToken,
      p_order_id: orderId,
      p_purchase_time: purchaseTimeMillis ? new Date(parseInt(purchaseTimeMillis)).toISOString() : new Date().toISOString(),
      p_status: mappedStatus,
      p_acknowledgement_state: mappedAckState,
      p_batch_id: batchId ?? null
    });

    if (rpcError) {
      console.error("RPC Error:", rpcError);
      return new Response(JSON.stringify({ error: 'Failed to process enrollment. Ensure the batch is active and product ID matches.', details: rpcError.message }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 4. Acknowledge Purchase if PURCHASED and NOT_ACKNOWLEDGED
    if (mappedStatus === 'purchased' && mappedAckState === 'not_acknowledged') {
      if (useMockBilling || isMockPurchase) {
        console.log("SANDBOX MODE ACTIVE: Mocking acknowledgement success.");
        await adminClient.rpc('update_purchase_acknowledgement', {
          p_purchase_token: purchaseToken,
          p_new_state: 'acknowledged'
        });
        mappedAckState = 'acknowledged';
      } else {
        // Production acknowledgement
        const ackUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`;
        
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
            p_purchase_token: purchaseToken,
            p_new_state: 'acknowledged'
          });
          mappedAckState = 'acknowledged';
        } else {
          await adminClient.rpc('update_purchase_acknowledgement', {
            p_purchase_token: purchaseToken,
            p_new_state: 'acknowledgement_pending'
          });
          mappedAckState = 'acknowledgement_pending';
          console.warn(`Failed to acknowledge token ${purchaseToken}, marked for retry.`);
        }
      }
    }

    return new Response(JSON.stringify({ 
      success: true, 
      purchaseId, 
      status: mappedStatus,
      acknowledgementState: mappedAckState 
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (err: any) {
    console.error(err);
    return new Response(JSON.stringify({ error: 'Internal Server Error', message: err.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

// Helper for Google Auth (OAuth2 JWT assertion via Web Crypto)
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
