// supabase/functions/send-notification/index.ts
// Supabase Edge Function to dispatch Firebase Cloud Messaging (FCM v1 HTTP API) push notifications with dynamic user templating

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface NotificationRequest {
  title: string;
  body: string;
  targetTier?: string; // 'all' | 'free' | 'pro' | 'farm'
  userId?: string;
  data?: Record<string, string>;
}

// Convert PEM private key to CryptoKey for Web Crypto API
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const cleanPem = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\\n/g, "")
    .replace(/\s+/g, "");

  const binaryDer = Uint8Array.from(atob(cleanPem), (c) => c.charCodeAt(0));

  return await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: { name: "SHA-256" },
    },
    false,
    ["sign"]
  );
}

// Base64Url encoder
function base64UrlEncode(str: string): string {
  return btoa(str)
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function base64UrlEncodeBuffer(buf: ArrayBuffer): string {
  let binary = "";
  const bytes = new Uint8Array(buf);
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return base64UrlEncode(binary);
}

// Generate Google OAuth2 Access Token for Firebase HTTP v1 API
async function getGoogleAccessToken(clientEmail: string, privateKeyPem: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const exp = now + 3600;

  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const claimSet = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: exp,
    iat: now,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedClaimSet = base64UrlEncode(JSON.stringify(claimSet));
  const unsignedToken = `${encodedHeader}.${encodedClaimSet}`;

  const privateKey = await importPrivateKey(privateKeyPem);
  const encoder = new TextEncoder();
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    encoder.encode(unsignedToken)
  );

  const signedJwt = `${unsignedToken}.${base64UrlEncodeBuffer(signature)}`;

  // Exchange JWT for OAuth2 Access Token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${signedJwt}`,
  });

  if (!tokenRes.ok) {
    const errText = await tokenRes.text();
    throw new Error(`Failed to exchange Google OAuth token: ${errText}`);
  }

  const tokenData = await tokenRes.json();
  return tokenData.access_token;
}

// Helper to interpolate dynamic variables
function formatTemplate(text: string, user: { displayName?: string; subscriptionTier?: string; streak?: number }): string {
  const name = (user.displayName && user.displayName.trim().isNotEmpty) ? user.displayName : "Plant Parent";
  const tier = (user.subscriptionTier || "free").toUpperCase();
  const streak = (user.streak ?? 0).toString();

  return text
    .replace(/{name}/gi, name)
    .replace(/{user_name}/gi, name)
    .replace(/{tier}/gi, tier)
    .replace(/{streak}/gi, streak);
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: NotificationRequest = await req.json();
    const { title, body, targetTier = "all", userId, data = {} } = payload;

    if (!title || !body) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: title, body" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get Firebase Credentials from Supabase Edge Function Secrets
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    let projectId = Deno.env.get("FIREBASE_PROJECT_ID") || "phytolens-f7c63";
    let clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
    let privateKey = Deno.env.get("FIREBASE_PRIVATE_KEY");

    if (serviceAccountJson) {
      try {
        const sa = JSON.parse(serviceAccountJson);
        projectId = sa.project_id || projectId;
        clientEmail = sa.client_email;
        privateKey = sa.private_key;
      } catch (_) {}
    }

    if (!clientEmail || !privateKey) {
      console.warn("FIREBASE_SERVICE_ACCOUNT secret is not set in Supabase.");
      return new Response(
        JSON.stringify({
          success: true,
          status: "pending_service_account",
          message: "Notification template received. Please configure FIREBASE_SERVICE_ACCOUNT secret in Supabase Secrets to dispatch real FCM v1 pushes.",
          payload: { title, body, targetTier, userId },
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Get OAuth2 Access Token for FCM v1
    const accessToken = await getGoogleAccessToken(clientEmail, privateKey);

    // 2. Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    let successCount = 0;
    let failureCount = 0;

    const hasTemplateVariables = title.includes("{") || body.includes("{");

    // Case A: Targeted single user
    if (userId) {
      const { data: user } = await supabase
        .from("users")
        .select("fcm_token, display_name, subscription_tier, streak")
        .eq("uid", userId)
        .single();

      if (user?.fcm_token) {
        const formattedTitle = formatTemplate(title, {
          displayName: user.display_name,
          subscriptionTier: user.subscription_tier,
          streak: user.streak,
        });
        const formattedBody = formatTemplate(body, {
          displayName: user.display_name,
          subscriptionTier: user.subscription_tier,
          streak: user.streak,
        });

        const message = {
          message: {
            token: user.fcm_token,
            notification: { title: formattedTitle, body: formattedBody },
            data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
          },
        };

        const res = await fetch(fcmEndpoint, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(message),
        });

        if (res.ok) successCount++;
        else failureCount++;
      }
    } 
    // Case B: Personalized Template Broadcast (Interpolates {name} for every logged in user)
    else if (hasTemplateVariables) {
      let query = supabase
        .from("users")
        .select("uid, fcm_token, display_name, subscription_tier, streak")
        .not("fcm_token", "is", null);

      if (targetTier !== "all") {
        query = query.eq("subscription_tier", targetTier.toLowerCase());
      }

      const { data: targetUsers, error: userError } = await query;

      if (!userError && targetUsers && targetUsers.length > 0) {
        // Send personalized messages in parallel batches
        const sendPromises = targetUsers.map(async (u) => {
          if (!u.fcm_token) return;

          const pTitle = formatTemplate(title, {
            displayName: u.display_name,
            subscriptionTier: u.subscription_tier,
            streak: u.streak,
          });
          const pBody = formatTemplate(body, {
            displayName: u.display_name,
            subscriptionTier: u.subscription_tier,
            streak: u.streak,
          });

          const message = {
            message: {
              token: u.fcm_token,
              notification: { title: pTitle, body: pBody },
              data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
            },
          };

          try {
            const res = await fetch(fcmEndpoint, {
              method: "POST",
              headers: {
                Authorization: `Bearer ${accessToken}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify(message),
            });
            if (res.ok) successCount++;
            else failureCount++;
          } catch (_) {
            failureCount++;
          }
        });

        await Promise.all(sendPromises);
      }
    }
    // Case C: Standard Topic Broadcast
    else {
      const topicName = targetTier === "all" ? "all" : `tier_${targetTier.toLowerCase()}`;

      const message = {
        message: {
          topic: topicName,
          notification: { title, body },
          data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
        },
      };

      const res = await fetch(fcmEndpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(message),
      });

      if (res.ok) {
        successCount++;
      } else {
        failureCount++;
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        sent: successCount,
        failed: failureCount,
        targetTier,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error sending push notification:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
