import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Clear, human-readable instructions without raw HTML markup
  const message = `
=========================================
       MODERN CLASSES PATNA
      Student Password Recovery
=========================================

To reset your password:
1. Open the Modern Classes Patna app on your device.
2. Tap "Forgot Password?" on the sign-in screen.
3. Enter your registered email address and the 6-digit recovery code from your email.
4. Set your new password directly in the app.

If you have the app installed on this device, open it now:
modernclasses://reset-callback

-----------------------------------------
Helpline: +91 6209016951
Office: Kumhrar / Musallahpur Hat, Patna
=========================================
`;

  return new Response(message.trim(), {
    headers: {
      ...corsHeaders,
      "Content-Type": "text/plain; charset=utf-8",
    },
  });
});
