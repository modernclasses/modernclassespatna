import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

const encodeMetadata = (value: string) =>
  btoa(String.fromCharCode(...new TextEncoder().encode(value)));

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_ANON_KEY") ??
      "";

    const cloudflareAccountId = Deno.env.get("CLOUDFLARE_ACCOUNT_ID") ?? "";
    const cloudflareApiToken = Deno.env.get("CLOUDFLARE_API_TOKEN") ?? "";
    const cloudflareCustomerCode = Deno.env.get("CLOUDFLARE_CUSTOMER_CODE") ?? "";

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid user session" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify role in public.profiles (allow both admin and teacher)
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    const userRole = profile?.role;
    if (profileError || !["admin", "teacher"].includes(userRole)) {
      return new Response(
        JSON.stringify({ error: "Forbidden: Faculty or Administrator privileges required" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = await req.json().catch(() => ({}));
    const action = body.action || "status";

    const adminOnlyActions = ["create_input", "delete_input", "delete_video"];
    if (adminOnlyActions.includes(action) && userRole !== "admin") {
      return new Response(
        JSON.stringify({ error: "Forbidden: Admin privileges required for this action" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. STATUS & ACCOUNT CONTEXT VERIFICATION
    if (action === "status") {
      return new Response(
        JSON.stringify({
          success: true,
          configured: !!(cloudflareAccountId && cloudflareApiToken),
          account_id_configured: !!cloudflareAccountId,
          account_id_preview: cloudflareAccountId
            ? `${cloudflareAccountId.substring(0, 4)}...${cloudflareAccountId.substring(cloudflareAccountId.length - 4)}`
            : null,
          has_api_token: !!cloudflareApiToken,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. LIST INPUTS
    if (action === "list_inputs") {
      const { data: localInputs, error: localErr } = await supabase
        .from("cloudflare_live_inputs")
        .select("*")
        .order("created_at", { ascending: false });

      if (localErr) {
        console.error("[cloudflare_stream_manager] Database lookup error:", localErr.message);
      }

      let cloudflareInputs: any[] = [];
      if (cloudflareAccountId && cloudflareApiToken) {
        try {
          const cfRes = await fetch(
            `https://api.cloudflare.com/client/v4/accounts/${cloudflareAccountId}/stream/live_inputs`,
            {
              method: "GET",
              headers: {
                Authorization: `Bearer ${cloudflareApiToken}`,
                "Content-Type": "application/json",
              },
            }
          );

          if (cfRes.ok) {
            const cfData = await cfRes.json();
            cloudflareInputs = cfData.result || [];
          }
        } catch (cfErr) {
          console.error("[cloudflare_stream_manager] Cloudflare API network error:", cfErr);
        }
      }

      return new Response(
        JSON.stringify({
          success: true,
          inputs: localInputs || [],
          cloudflare_synced: cloudflareInputs.length > 0,
          account_id: cloudflareAccountId || null,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. CREATE INPUT
    if (action === "create_input") {
      const name = body.name?.trim() || "Live Classroom Ingest";
      let uid = body.uid?.trim() || "";
      let rtmpsUrl = body.rtmps_url?.trim() || "rtmps://live.cloudflare.com:443/live/";
      let streamKey = body.stream_key?.trim() || "";
      let playbackUrl = body.playback_url?.trim() || "";
      const accountId = body.account_id?.trim() || cloudflareAccountId;

      if (cloudflareAccountId && cloudflareApiToken && !uid) {
        try {
          const cfRes = await fetch(
            `https://api.cloudflare.com/client/v4/accounts/${cloudflareAccountId}/stream/live_inputs`,
            {
              method: "POST",
              headers: {
                Authorization: `Bearer ${cloudflareApiToken}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                meta: { name },
                recording: { mode: "automatic", timeoutSeconds: 300 },
              }),
            }
          );

          if (!cfRes.ok) {
            const errData = await cfRes.json().catch(() => ({}));
            return new Response(
              JSON.stringify({
                error: `Cloudflare Stream API error (${cfRes.status}): ${JSON.stringify(errData.errors || errData)}`,
              }),
              { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
          }

          const cfData = await cfRes.json();
          const result = cfData.result;
          uid = result.uid;
          rtmpsUrl = result.rtmps?.url || "rtmps://live.cloudflare.com:443/live/";
          streamKey = result.rtmps?.streamKey || "";
          playbackUrl = `https://customer-${cloudflareAccountId}.cloudflarestream.com/${uid}/manifest/video.m3u8`;
        } catch (err) {
          console.error("[cloudflare_stream_manager] Failed to call Cloudflare API:", err);
          return new Response(
            JSON.stringify({ error: `Cloudflare network error: ${err}` }),
            { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }

      if (!uid || !streamKey) {
        return new Response(
          JSON.stringify({ error: "Cloudflare Live Input UID and Stream Key are required." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data: inserted, error: insertErr } = await supabase
        .from("cloudflare_live_inputs")
        .upsert(
          {
            uid,
            name,
            rtmps_url: rtmpsUrl,
            stream_key: streamKey,
            playback_url: playbackUrl,
            account_id: accountId || null,
            created_by: user.id,
            updated_at: new Date().toISOString(),
          },
          { onConflict: "uid" }
        )
        .select()
        .single();

      if (insertErr) {
        return new Response(
          JSON.stringify({ error: `Failed to persist to Supabase: ${insertErr.message}` }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({ success: true, input: inserted }),
        { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. GET LIVE STATUS
    if (action === "get_live_status") {
      const uid = body.uid?.trim();
      if (!uid) {
        return new Response(
          JSON.stringify({ error: "Missing required parameter: uid" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (cloudflareAccountId && cloudflareApiToken) {
        try {
          const cfRes = await fetch(
            `https://api.cloudflare.com/client/v4/accounts/${cloudflareAccountId}/stream/live_inputs/${uid}`,
            {
              method: "GET",
              headers: {
                Authorization: `Bearer ${cloudflareApiToken}`,
                "Content-Type": "application/json",
              },
            }
          );

          if (cfRes.ok) {
            const cfData = await cfRes.json();
            const result = cfData.result;
            const state = result?.status?.current?.state ?? "disconnected";
            const isLive = state === "connected";

            return new Response(
              JSON.stringify({
                success: true,
                is_live: isLive,
                state: state,
                uid: uid,
                recording_mode: result?.recording?.mode ?? "automatic",
              }),
              { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
          } else {
            return new Response(
              JSON.stringify({
                success: true,
                is_live: false,
                state: "unavailable",
                error: `Cloudflare returned status ${cfRes.status}`,
              }),
              { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
          }
        } catch (cfErr) {
          return new Response(
            JSON.stringify({
              success: true,
              is_live: false,
              state: "unavailable",
              error: `Network error checking status: ${cfErr}`,
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }

      // Fallback if Cloudflare credentials are not configured
      return new Response(
        JSON.stringify({
          success: true,
          is_live: true,
          state: "connected",
          mock: true,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. SYNC BROADCAST RECORDING
    if (action === "sync_broadcast_recording") {
      let liveInputUid = body.live_input_uid?.trim() || "";
      const liveClassId = body.live_class_id?.trim();
      const batchId = body.batch_id?.trim();
      const courseId = body.course_id?.trim();
      const title = body.title?.trim() || "Live Lecture Recording";
      const teacherId = body.teacher_id?.trim() || user.id;
      const clientPlaybackUrl = body.playback_url?.trim() || "";

      // Extract 32-char hex Live Input UID if stream_key format (keykUID) was provided
      if (liveInputUid.includes("k") && liveInputUid.length > 32) {
        liveInputUid = liveInputUid.substring(liveInputUid.indexOf("k") + 1);
      }

      // If clientPlaybackUrl has a 32-char hex UID, extract customer subdomain & UID
      let extractedUidFromPlayback = "";
      const uidMatch = clientPlaybackUrl.match(/([a-f0-9]{32})/i);
      if (uidMatch) {
        extractedUidFromPlayback = uidMatch[1];
      }

      let videoUid = "";
      let playbackUrl = clientPlaybackUrl;
      let thumbnailUrl = "";
      let durationSeconds = body.duration_seconds || 0;
      let status = "processing"; // Cloudflare recordings take ~60 seconds to finalize

      const effectiveInputUid = liveInputUid || extractedUidFromPlayback;

      if (cloudflareAccountId && cloudflareApiToken && effectiveInputUid) {
        try {
          const cfRes = await fetch(
            `https://api.cloudflare.com/client/v4/accounts/${cloudflareAccountId}/stream/live_inputs/${effectiveInputUid}/videos`,
            {
              method: "GET",
              headers: {
                Authorization: `Bearer ${cloudflareApiToken}`,
                "Content-Type": "application/json",
              },
            }
          );

          if (cfRes.ok) {
            const cfData = await cfRes.json();
            const videos = cfData.result || [];
            if (videos.length > 0) {
              // Take latest video generated by this live input
              const latestVideo = videos[0];
              videoUid = latestVideo.uid;
              const cfState = latestVideo.status?.state;
              if (cfState === "ready") {
                status = "ready";
              } else if (cfState === "error") {
                status = "failed";
              } else {
                status = "processing";
              }

              if (latestVideo.duration && latestVideo.duration > 0) {
                durationSeconds = Math.round(latestVideo.duration);
              }
              playbackUrl = latestVideo.playback?.hls || playbackUrl ||
                `https://customer-${cloudflareAccountId}.cloudflarestream.com/${videoUid}/manifest/video.m3u8`;
              thumbnailUrl = latestVideo.thumbnail ||
                `https://customer-${cloudflareAccountId}.cloudflarestream.com/${videoUid}/thumbnails/thumbnail.jpg`;
            }
          }
        } catch (cfErr) {
          console.warn("[cloudflare_stream_manager] Failed to fetch live input videos from Cloudflare:", cfErr);
        }
      }

      // Fallback video UID and playback URL preservation
      if (!videoUid) {
        videoUid = extractedUidFromPlayback || `rec_${(liveClassId || Date.now().toString()).replace(/-/g, "")}`;
        if (!playbackUrl) {
          playbackUrl = `https://videodelivery.net/${videoUid}/manifest/video.m3u8`;
        }
        // If broadcast has valid playback URL and duration > 0, default to processing (~60s buffer)
        status = "processing";
      }

      // Authoritative database sync using sync_lecture_recording RPC or direct upsert
      try {
        const { data: rpcRes, error: rpcErr } = await supabase.rpc(
          "sync_lecture_recording",
          {
            p_batch_id: batchId,
            p_course_id: courseId,
            p_title: title,
            p_video_uid: videoUid,
            p_playback_url: playbackUrl,
            p_live_class_id: liveClassId || null,
            p_live_input_uid: effectiveInputUid || null,
            p_teacher_id: teacherId,
            p_thumbnail_url: thumbnailUrl || null,
            p_duration_seconds: durationSeconds,
            p_status: status,
            p_start_time: body.start_time || new Date().toISOString(),
            p_end_time: body.end_time || new Date().toISOString(),
            p_is_published: true,
          }
        );

        if (!rpcErr && rpcRes && rpcRes.recording) {
          return new Response(
            JSON.stringify({
              success: true,
              recording: rpcRes.recording,
              status: status,
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      } catch (rpcCatch) {
        console.warn("[cloudflare_stream_manager] sync_lecture_recording RPC notice:", rpcCatch);
      }

      // Fallback direct upsert into public.lecture_recordings
      const recordingPayload: any = {
        live_class_id: liveClassId || null,
        course_id: courseId,
        batch_id: batchId,
        teacher_id: teacherId,
        title: title,
        live_input_uid: effectiveInputUid || null,
        video_uid: videoUid,
        playback_url: playbackUrl,
        thumbnail_url: thumbnailUrl || null,
        duration_seconds: durationSeconds,
        status: status,
        start_time: body.start_time || new Date().toISOString(),
        end_time: body.end_time || new Date().toISOString(),
        is_published: true,
        updated_at: new Date().toISOString(),
      };

      const { data: recording, error: recErr } = await supabase
        .from("lecture_recordings")
        .upsert(recordingPayload, { onConflict: "video_uid" })
        .select()
        .single();

      if (recErr) {
        console.error("[cloudflare_stream_manager] Recording upsert error:", recErr.message);
      }

      // Also update public.live_classes if liveClassId provided
      if (liveClassId) {
        await supabase
          .from("live_classes")
          .update({
            recording_url: playbackUrl,
            cloudflare_video_uid: videoUid,
            recording_status: status,
            actual_duration_seconds: durationSeconds,
            status: "ended",
          })
          .eq("id", liveClassId);
      }

      return new Response(
        JSON.stringify({
          success: true,
          recording: recording || recordingPayload,
          status: status,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 6. REFRESH RECORDING STATUS
    if (action === "refresh_recording") {
      const videoUid = body.video_uid?.trim();
      if (!videoUid) {
        return new Response(
          JSON.stringify({ error: "Missing required parameter: video_uid" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      let status = "processing";
      let durationSeconds = 0;
      let playbackUrl = "";

      if (cloudflareAccountId && cloudflareApiToken && videoUid.startsWith("rec_")) {
        // Look up the recording row in lecture_recordings to get live_input_uid
        try {
          const { data: recRow } = await supabase
            .from("lecture_recordings")
            .select("live_input_uid, live_class_id")
            .eq("video_uid", videoUid)
            .maybeSingle();

          const inputUid = recRow?.live_input_uid;
          if (inputUid) {
            const cfRes = await fetch(
              `https://api.cloudflare.com/client/v4/accounts/${cloudflareAccountId}/stream/live_inputs/${inputUid}/videos`,
              {
                method: "GET",
                headers: {
                  Authorization: `Bearer ${cloudflareApiToken}`,
                  "Content-Type": "application/json",
                },
              }
            );

            if (cfRes.ok) {
              const cfData = await cfRes.json();
              const videos = cfData.result || [];
              if (videos.length > 0) {
                const latestVideo = videos[0];
                const realUid = latestVideo.uid;
                const cfState = latestVideo.status?.state;
                status = cfState === "ready" ? "ready" : (cfState === "error" ? "failed" : "processing");
                if (latestVideo.duration && latestVideo.duration > 0) {
                  durationSeconds = Math.round(latestVideo.duration);
                }
                playbackUrl = latestVideo.playback?.hls ||
                  `https://customer-${cloudflareAccountId}.cloudflarestream.com/${realUid}/manifest/video.m3u8`;

                // Update database record with the real Cloudflare video UID
                await supabase
                  .from("lecture_recordings")
                  .update({
                    video_uid: realUid,
                    playback_url: playbackUrl,
                    duration_seconds: durationSeconds,
                    status: status,
                    updated_at: new Date().toISOString(),
                  })
                  .eq("video_uid", videoUid);

                if (recRow.live_class_id) {
                  await supabase
                    .from("live_classes")
                    .update({
                      cloudflare_video_uid: realUid,
                      recording_url: playbackUrl,
                      actual_duration_seconds: durationSeconds,
                      recording_status: status,
                    })
                    .eq("id", recRow.live_class_id);
                }

                return new Response(
                  JSON.stringify({
                    success: true,
                    recording: { video_uid: realUid, playback_url: playbackUrl, status },
                    status: status,
                  }),
                  { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
                );
              }
            }
          }
        } catch (recErr) {
          console.warn("[cloudflare_stream_manager] rec_ resolution notice:", recErr);
        }
      }

      if (cloudflareAccountId && cloudflareApiToken && !videoUid.startsWith("cf_rec_") && !videoUid.startsWith("rec_")) {
        try {
          const cfRes = await fetch(
            `https://api.cloudflare.com/client/v4/accounts/${cloudflareAccountId}/stream/${videoUid}`,
            {
              method: "GET",
              headers: {
                Authorization: `Bearer ${cloudflareApiToken}`,
                "Content-Type": "application/json",
              },
            }
          );

          if (cfRes.ok) {
            const cfData = await cfRes.json();
            const vid = cfData.result;
            const cfState = vid?.status?.state;
            if (cfState === "ready") {
              status = "ready";
            } else if (cfState === "error") {
              status = "failed";
            } else {
              status = "processing";
            }

            if (vid?.duration && vid.duration > 0) {
              durationSeconds = Math.round(vid.duration);
            }
            playbackUrl = vid?.playback?.hls ||
              `https://customer-${cloudflareAccountId}.cloudflarestream.com/${videoUid}/manifest/video.m3u8`;
          }
        } catch (cfErr) {
          console.warn("[cloudflare_stream_manager] Error fetching video details:", cfErr);
        }
      } else {
        // If simulated/mock, promote processing -> ready
        status = "ready";
      }

      const updates: any = {
        status: status,
        updated_at: new Date().toISOString(),
      };
      if (durationSeconds > 0) updates.duration_seconds = durationSeconds;
      if (playbackUrl) updates.playback_url = playbackUrl;

      const { data: updatedRec, error: upErr } = await supabase
        .from("lecture_recordings")
        .update(updates)
        .eq("video_uid", videoUid)
        .select()
        .single();

      if (upErr) {
        console.warn("[cloudflare_stream_manager] Update recording error:", upErr.message);
      }

      // Update associated live_classes record
      await supabase
        .from("live_classes")
        .update({
          recording_status: status,
        })
        .eq("cloudflare_video_uid", videoUid);

      return new Response(
        JSON.stringify({
          success: true,
          recording: updatedRec || { video_uid: videoUid, status },
          status: status,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 7. DELETE INPUT (Admin only, Requires "CONFIRM")
    if (action === "delete_input") {
      const uid = body.uid?.trim();
      const confirmation = body.confirmation?.trim();

      if (!uid) {
        return new Response(
          JSON.stringify({ error: "Missing required parameter: uid" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (confirmation !== "CONFIRM") {
        return new Response(
          JSON.stringify({
            error: "Action rejected. Explicit confirmation keyword 'CONFIRM' must be provided.",
          }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (cloudflareAccountId && cloudflareApiToken) {
        try {
          await fetch(
            `https://api.cloudflare.com/client/v4/accounts/${cloudflareAccountId}/stream/live_inputs/${uid}`,
            {
              method: "DELETE",
              headers: {
                Authorization: `Bearer ${cloudflareApiToken}`,
                "Content-Type": "application/json",
              },
            }
          );
        } catch (cfErr) {
          console.warn("[cloudflare_stream_manager] Cloudflare API delete request warning:", cfErr);
        }
      }

      const { error: delErr } = await supabase
        .from("cloudflare_live_inputs")
        .delete()
        .eq("uid", uid);

      if (delErr) {
        return new Response(
          JSON.stringify({ error: `Failed to delete from database: ${delErr.message}` }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({ success: true, message: `Live input ${uid} deleted successfully.` }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 8. CREATE DIRECT CREATOR UPLOAD (Teacher & Admin)
    if (action === "create_tus_upload") {
      const uploadLength = Number(body.upload_length);
      const maxDurationSeconds = body.max_duration_seconds || 14400;
      const title = body.title?.trim() || "Prerecorded Lecture";

      if (!Number.isSafeInteger(uploadLength) || uploadLength <= 0) {
        return new Response(
          JSON.stringify({ error: "upload_length must be a positive integer" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (!cloudflareAccountId || !cloudflareApiToken) {
        return new Response(
          JSON.stringify({ error: "Cloudflare credentials not configured" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const metadata = `maxDurationSeconds ${encodeMetadata(maxDurationSeconds.toString())},name ${encodeMetadata(title)}`;
      const cfRes = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${cloudflareAccountId}/stream?direct_user=true`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${cloudflareApiToken}`,
            "Tus-Resumable": "1.0.0",
            "Upload-Length": uploadLength.toString(),
            "Upload-Metadata": metadata,
          },
        }
      );

      if (!cfRes.ok) {
        const errorBody = await cfRes.text();
        console.error("[cloudflare_stream_manager] TUS upload creation failed:", cfRes.status, errorBody);
        return new Response(
          JSON.stringify({ error: `Cloudflare TUS upload creation failed (${cfRes.status}): ${errorBody}` }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const uploadUrl = cfRes.headers.get("Location");
      if (!uploadUrl) {
        return new Response(
          JSON.stringify({ error: "Cloudflare did not return a TUS upload URL" }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const uidFromHeader = cfRes.headers.get("stream-media-id");
      const uid = uidFromHeader || (uploadUrl.split("/").pop() ?? "").split("?")[0];
      const playbackUrl = uid
        ? (cloudflareCustomerCode
            ? `https://customer-${cloudflareCustomerCode}.cloudflarestream.com/${uid}/manifest/video.m3u8`
            : `https://videodelivery.net/${uid}/manifest/video.m3u8`)
        : null;
      const thumbnailUrl = uid
        ? (cloudflareCustomerCode
            ? `https://customer-${cloudflareCustomerCode}.cloudflarestream.com/${uid}/thumbnails/thumbnail.jpg`
            : `https://videodelivery.net/${uid}/thumbnails/thumbnail.jpg`)
        : null;

      return new Response(
        JSON.stringify({
          success: true,
          upload_url: uploadUrl,
          uid: uid,
          playback_url: playbackUrl,
          thumbnail_url: thumbnailUrl,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 9. CREATE DIRECT CREATOR UPLOAD (Teacher & Admin)
    if (action === "create_direct_upload") {
      const maxDurationSeconds = body.max_duration_seconds || 14400; // 4 hours
      const title = body.title?.trim() || "Prerecorded Lecture";
      const batchId = body.batch_id?.trim() || "";
      const courseId = body.course_id?.trim() || "";

      if (!cloudflareAccountId || !cloudflareApiToken) {
        return new Response(
          JSON.stringify({ error: "Cloudflare credentials not configured" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      try {
        const cfRes = await fetch(
          `https://api.cloudflare.com/client/v4/accounts/${cloudflareAccountId}/stream/direct_upload`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${cloudflareApiToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              maxDurationSeconds,
              meta: {
                name: title,
                batch_id: batchId,
                course_id: courseId,
                uploaded_by: user.id,
              },
            }),
          }
        );

        if (!cfRes.ok) {
          const errData = await cfRes.json().catch(() => ({}));
          console.error("[cloudflare_stream_manager] Direct upload creation failed:", errData);
          return new Response(
            JSON.stringify({
              error: `Cloudflare Direct Upload error (${cfRes.status}): ${JSON.stringify(errData.errors || errData)}`,
            }),
            { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        const cfData = await cfRes.json();
        const uploadURL = cfData.result?.uploadURL;
        const uid = cfData.result?.uid;
        const playbackUrl = uid
          ? (cloudflareCustomerCode
              ? `https://customer-${cloudflareCustomerCode}.cloudflarestream.com/${uid}/manifest/video.m3u8`
              : `https://videodelivery.net/${uid}/manifest/video.m3u8`)
          : null;
        const thumbnailUrl = uid
          ? (cloudflareCustomerCode
              ? `https://customer-${cloudflareCustomerCode}.cloudflarestream.com/${uid}/thumbnails/thumbnail.jpg`
              : `https://videodelivery.net/${uid}/thumbnails/thumbnail.jpg`)
          : null;

        return new Response(
          JSON.stringify({
            success: true,
            upload_url: uploadURL,
            uid: uid,
            playback_url: playbackUrl,
            thumbnail_url: thumbnailUrl,
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      } catch (err: any) {
        console.error("[cloudflare_stream_manager] Network error during direct upload creation:", err);
        return new Response(
          JSON.stringify({ error: `Cloudflare network error: ${err?.message || err}` }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // 10. LIST STORED VIDEOS (Admin)
    if (action === "list_videos") {
      if (!cloudflareAccountId || !cloudflareApiToken) {
        return new Response(
          JSON.stringify({ error: "Cloudflare credentials not configured" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      try {
        const cfRes = await fetch(
          `https://api.cloudflare.com/client/v4/accounts/${cloudflareAccountId}/stream?limit=100`,
          {
            headers: {
              Authorization: `Bearer ${cloudflareApiToken}`,
              "Content-Type": "application/json",
            },
          }
        );
        const data = await cfRes.json();
        const totalDurationMinutes = (data.result || []).reduce(
          (sum: number, v: any) => sum + (v.duration ? v.duration / 60 : 0),
          0
        );
        return new Response(
          JSON.stringify({
            success: true,
            total_videos: (data.result || []).length,
            total_duration_minutes: Math.round(totalDurationMinutes * 100) / 100,
            videos: (data.result || []).map((v: any) => ({
              uid: v.uid,
              name: v.meta?.name || "Untitled",
              duration_seconds: v.duration,
              duration_minutes: Math.round(((v.duration || 0) / 60) * 10) / 10,
              created: v.created,
              readyToStream: v.readyToStream,
              status: v.status?.state,
            })),
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      } catch (err: any) {
        return new Response(
          JSON.stringify({ error: `Cloudflare API error: ${err?.message || err}` }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // 11. DELETE STORED VIDEO (Admin Only)
    if (action === "delete_video") {
      const videoUid = body.video_uid?.trim();
      if (!videoUid) {
        return new Response(
          JSON.stringify({ error: "Missing video_uid parameter" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      if (!cloudflareAccountId || !cloudflareApiToken) {
        return new Response(
          JSON.stringify({ error: "Cloudflare credentials not configured" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      try {
        const cfRes = await fetch(
          `https://api.cloudflare.com/client/v4/accounts/${cloudflareAccountId}/stream/${videoUid}`,
          {
            method: "DELETE",
            headers: {
              Authorization: `Bearer ${cloudflareApiToken}`,
              "Content-Type": "application/json",
            },
          }
        );
        return new Response(
          JSON.stringify({ success: cfRes.ok, status: cfRes.status }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      } catch (err: any) {
        return new Response(
          JSON.stringify({ error: `Cloudflare API error: ${err?.message || err}` }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    return new Response(
      JSON.stringify({ error: `Unknown action: ${action}` }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("[cloudflare_stream_manager] Unhandled exception:", err);
    return new Response(
      JSON.stringify({ error: `Internal server error: ${err?.message || err}` }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
