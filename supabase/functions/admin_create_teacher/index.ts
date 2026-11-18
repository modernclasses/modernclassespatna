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
    const body = await req.json();
    const { email, password, fullName } = body;

    if (!email || !password || !fullName) {
      console.error('Validation failed: missing fields');
      return new Response(JSON.stringify({ error: 'email, password, and fullName are required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      console.error('Authorization header is missing');
      return new Response(JSON.stringify({ error: 'Authorization header is missing' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
      console.error('Missing environment variables');
      return new Response(JSON.stringify({ error: 'Server misconfiguration' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Initialize Supabase Admin Client
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);

    // 1. Verify caller identity using JWT token
    console.log('Fetching caller user...');
    const token = authHeader.replace(/^Bearer\s+/i, '');
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token);
    if (authError || !user) {
      console.error('Invalid token or user not found:', authError);
      return new Response(JSON.stringify({ error: 'Session expired or invalid login. Please sign out and sign in again.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 2. Check if caller has admin role in profiles
    console.log('Checking if caller is admin...');
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .maybeSingle();

    if (profileError || profile?.role !== 'admin') {
      console.error('Forbidden: User is not an admin', profileError, profile);
      return new Response(JSON.stringify({ error: 'Forbidden: Administrator privileges required.' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 3. Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
    if (!emailRegex.test(email.trim())) {
      console.error('Invalid email format:', email);
      return new Response(JSON.stringify({ 
        error: `Invalid email address "${email}". Email must include a domain (e.g. name@gmail.com or name@modernclasses.in).` 
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 4. Create the auth user
    console.log('Attempting to create user in auth.users...');
    const { data: newUserData, error: createUserError } = await supabaseAdmin.auth.admin.createUser({
      email: email.trim().toLowerCase(),
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName.trim() },
    });

    if (createUserError) {
      console.error('createUserError:', createUserError.message);
      let errorMsg = createUserError.message;
      if (errorMsg.toLowerCase().includes('already') || errorMsg.toLowerCase().includes('exists')) {
        errorMsg = `An account with the email "${email}" already exists. Please use a different email or appoint the existing account.`;
      }
      return new Response(JSON.stringify({ error: errorMsg }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const newUserId = newUserData.user.id;
    console.log('User created successfully:', newUserId);

    // 5. Upsert profile with role = teacher (service_role bypasses RLS and triggers)
    console.log('Updating profile to teacher role...');
    const { error: profileError2 } = await supabaseAdmin
      .from('profiles')
      .upsert({
        id: newUserId,
        full_name: fullName.trim(),
        email: email.trim().toLowerCase(),
        role: 'teacher',
        is_active: true,
        updated_at: new Date().toISOString(),
      });

    if (profileError2) {
      console.error('Profile upsert failed:', profileError2.message);
      return new Response(JSON.stringify({ error: 'User created but role update failed: ' + profileError2.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    console.log('Teacher created and role set to teacher successfully:', newUserId);
    return new Response(JSON.stringify({ success: true, userId: newUserId }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error('Internal Server Error:', error);
    return new Response(JSON.stringify({ error: 'Internal Server Error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
