import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

async function verifyRazorpaySignature(orderId: string, paymentId: string, signature: string, secret: string) {
  const encoder = new TextEncoder();
  const data = encoder.encode(orderId + "|" + paymentId);
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"]
  );
  
  const hmac = await crypto.subtle.sign("HMAC", key, data);
  const generatedSignature = Array.from(new Uint8Array(hmac))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
  return generatedSignature === signature;
}

async function verifyWebhookSignature(payload: string, signature: string, secret: string) {
  const encoder = new TextEncoder();
  const data = encoder.encode(payload);
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"]
  );
  
  const hmac = await crypto.subtle.sign("HMAC", key, data);
  const generatedSignature = Array.from(new Uint8Array(hmac))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
    
  return generatedSignature === signature;
}

serve(async (req: Request) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // We will process the body differently based on the URL or action.
  // Webhooks usually don't send CORS OPTIONS, and they send raw JSON without action params.
  const url = new URL(req.url);
  
  if (url.pathname.endsWith('/webhook')) {
    try {
      const signature = req.headers.get('x-razorpay-signature');
      if (!signature) throw new Error('Missing webhook signature');

      const rawBody = await req.text();
      const webhookSecret = Deno.env.get('RAZORPAY_KEY_SECRET');
      
      if (!webhookSecret) throw new Error('Webhook secret not configured');

      const isValid = await verifyWebhookSignature(rawBody, signature, webhookSecret);
      if (!isValid) {
        return new Response('Invalid signature', { status: 400 });
      }

      const payload = JSON.parse(rawBody);
      
      if (payload.event === 'order.paid') {
        const order = payload.payload.order.entity;
        const payment = payload.payload.payment?.entity;
        const notes = order.notes || {};
        const userId = notes.user_id;
        const plan = notes.plan;
        const amount = payment?.amount || order.amount; // in paise
        const orderId = order.id;

        if (userId && plan) {
          const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
          const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
          const supabase = createClient(supabaseUrl, supabaseServiceKey)

          // Idempotency: Check if this order was already processed
          const { data: existingPayment } = await supabase
            .from('payments')
            .select('id')
            .eq('razorpay_order_id', orderId)
            .single();

          if (!existingPayment) {
            // Update user subscription
            const expiryDate = new Date();
            expiryDate.setDate(expiryDate.getDate() + 30);

            await supabase
              .from('users')
              .update({ 
                subscription_tier: plan,
                subscription_expiry: expiryDate.toISOString()
              })
              .eq('uid', userId);

            // Record payment
            await supabase.from('payments').insert({
              user_id: userId,
              amount: Math.round(amount / 100),
              plan: plan,
              razorpay_order_id: orderId,
              razorpay_payment_id: payment?.id || 'webhook',
              status: 'completed'
            });
          }
        }
      }

      return new Response(JSON.stringify({ status: 'ok' }), { headers: corsHeaders, status: 200 });
    } catch (error: any) {
      console.error('Webhook Error:', error);
      return new Response('Webhook Error', { status: 400 });
    }
  }

  try {
    const { action, ...params } = await req.json()
    
    // Create Supabase Client with service role to update user table securely
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Razorpay credentials
    const keyId = Deno.env.get('RAZORPAY_KEY_ID')
    const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET')

    if (!keyId || !keySecret) {
      throw new Error('Razorpay credentials not configured')
    }

    if (action === 'create_order') {
      const { amount, currency = 'INR', receipt = 'receipt_1' } = params

      const auth = btoa(`${keyId}:${keySecret}`)
      const response = await fetch('https://api.razorpay.com/v1/orders', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Basic ${auth}`
        },
        body: JSON.stringify({ 
          amount, 
          currency, 
          receipt,
          notes: {
            user_id: params.user_id,
            plan: params.plan
          }
        })
      })

      if (!response.ok) {
        const err = await response.json()
        throw new Error(`Razorpay Error: ${JSON.stringify(err)}`)
      }

      const order = await response.json()
      return new Response(
        JSON.stringify(order),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } 
    
    else if (action === 'verify_payment') {
      const { razorpay_payment_id, razorpay_order_id, razorpay_signature, plan, amount } = params

      // Verify the signature
      const isValid = await verifyRazorpaySignature(
        razorpay_order_id, 
        razorpay_payment_id, 
        razorpay_signature, 
        keySecret
      )

      if (!isValid) {
        throw new Error('Invalid payment signature')
      }

      // Get user id from request (who made the request)
      const authHeader = req.headers.get('Authorization')!
      const token = authHeader.replace('Bearer ', '')
      const { data: { user }, error: userError } = await supabase.auth.getUser(token)
      
      if (userError || !user) {
        throw new Error('Unauthorized')
      }

      // Payment is verified, update the user in database
      // Calculate 30 days from now
      const expiryDate = new Date()
      expiryDate.setDate(expiryDate.getDate() + 30)

      const { error: updateError } = await supabase
        .from('users')
        .update({ 
          subscription_tier: plan,
          subscription_expiry: expiryDate.toISOString()
        })
        .eq('uid', user.id)

      if (updateError) {
        throw new Error(`Database update failed: ${updateError.message}`)
      }

      // Save payment record (convert paise back to rupees for db)
      const rupeeAmount = Math.round(amount / 100);
      
      // Idempotency check: see if payment or order already exists
      const { data: existingPayment } = await supabase
        .from('payments')
        .select('id')
        .eq('razorpay_order_id', razorpay_order_id)
        .single();
        
      if (!existingPayment) {
        await supabase.from('payments').insert({
          user_id: user.id,
          amount: rupeeAmount,
          plan: plan,
          razorpay_order_id: razorpay_order_id,
          razorpay_payment_id: razorpay_payment_id,
          status: 'completed'
        })
      }

      return new Response(
        JSON.stringify({ success: true, expiry: expiryDate.toISOString() }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    throw new Error('Invalid action')

  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
