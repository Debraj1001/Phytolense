// web/src/services/supabase.js
import { createClient } from '@supabase/supabase-js';

export const SUPABASE_URL = 'https://fpvwkchsxxfvpprpwwfc.supabase.co';
export const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZwdndrY2hzeHhmdnBwcnB3d2ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY0NzIzMzMsImV4cCI6MjEwMjA0ODMzM30.-KOfF0WVCKjzIHoVp-pwy3eMxJbSwMplyEHtpB_rTZQ';
export const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZwdndrY2hzeHhmdnBwcnB3d2ZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NjQ3MjMzMywiZXhwIjoyMTAyMDQ4MzMzfQ.Wpug3LGF4K8yv3NYpq6MR9LE-aPXhXARPr8XeDXV7zE';

// Standard public client
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Privileged admin client for admin management operations (no session persistence to avoid GoTrueClient collisions)
export const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
    detectSessionInUrl: false
  }
});

export const DESIGNATED_ADMIN_EMAIL = 'noreplay.gkk26@gmail.com';
export const DESIGNATED_ADMIN_UID = 'dacb126a-7307-4751-8f9f-8fb45f0ee674';

// ─── Admin Check ─────────────────────────────────────────────────────────────
export async function verifyAdminStatus(email, uid) {
  try {
    if (!email) return false;
    const cleanEmail = email.toLowerCase().trim();

    // Check database public.admins table
    const { data, error } = await supabaseAdmin
      .from('admins')
      .select('*')
      .eq('email', cleanEmail)
      .eq('is_active', true)
      .maybeSingle();

    if (data) return data;
    return null;
  } catch (err) {
    console.error('Error verifying admin status:', err);
    return null;
  }
}

// ─── Admin Login (Strict Credentials with Supabase Auth) ─────────────────────
export async function authenticateAdmin(email, password) {
  const cleanEmail = email.trim().toLowerCase();

  if (!cleanEmail || !password) {
    return { success: false, error: 'Please provide both admin email and password.' };
  }

  try {
    // 1. Authenticate with Supabase Auth using credentials created by user
    const { data, error } = await supabase.auth.signInWithPassword({
      email: cleanEmail,
      password: password
    });

    if (error) {
      return { success: false, error: error.message || 'Invalid admin credentials.' };
    }

    if (!data?.user) {
      return { success: false, error: 'No user session returned by authentication server.' };
    }

    // 2. Verify against public.admins table
    const adminRecord = await verifyAdminStatus(cleanEmail, data.user.id);
    if (!adminRecord) {
      await supabase.auth.signOut();
      return { 
        success: false, 
        error: 'Access Denied: This account is not registered in the administrator table.' 
      };
    }

    // 3. Update last login timestamp
    try {
      await supabaseAdmin
        .from('admins')
        .update({ last_login: new Date().toISOString() })
        .eq('id', adminRecord.id);
    } catch (_) {}

    return { 
      success: true, 
      user: {
        ...data.user,
        role: adminRecord.role || 'super_admin',
        display_name: adminRecord.display_name || data.user.email
      }
    };
  } catch (err) {
    return { success: false, error: err.message || 'Authentication failed.' };
  }
}

// ─── App Config ──────────────────────────────────────────────────────────────
export async function fetchAppConfig() {
  try {
    const { data, error } = await supabaseAdmin
      .from('app_config')
      .select('*')
      .eq('id', 1)
      .maybeSingle();

    if (error || !data) throw error;
    return data;
  } catch (err) {
    console.warn('Using default app config fallback:', err);
    return {
      id: 1,
      free_tier_days: 2,
      free_daily_scan_limit: 15,
      pro_daily_scan_limit: 50,
      farm_daily_scan_limit: 100,
      free_daily_ai_limit: 15,
      pro_daily_ai_limit: 50,
      farm_daily_ai_limit: 100,
      farm_creation_limit_free: 1,
      farm_creation_limit_pro: 5,
      farm_creation_limit_farm: 100,
      pro_monthly_price: 49,
      farm_monthly_price: 199,
      garden_enabled: true,
      bulk_export_enabled: true,
      maintenance_mode: false,
      latest_version: '1.0.4',
      latest_version_code: 5,
      apk_size_mb: '124 MB',
      min_supported_version: '1.0.0',
      download_url_android: 'https://github.com/Debraj1001/Phytolense/releases/download/v1.0.4/app-release.apk',
      download_url_github_release: 'https://github.com/Debraj1001/Phytolense/releases/tag/v1.0.4',
      download_url_playstore: 'https://play.google.com/store/apps/details?id=com.phytolens.app',
      download_url_ios: 'https://testflight.apple.com/join/phytolens',
      download_url_web: 'https://phytolens.agritech.org',
      qr_primary_target: 'android',
      qr_foreground_color: '#0F172A',
      qr_error_correction: 'M',
      qr_logo_enabled: false
    };
  }
}

export async function saveAppConfig(updates) {
  try {
    const { data, error } = await supabaseAdmin
      .from('app_config')
      .update({
        ...updates,
        updated_at: new Date().toISOString()
      })
      .eq('id', 1)
      .select()
      .single();

    if (error) throw error;
    return { success: true, data };
  } catch (err) {
    console.error('Error saving app_config:', err);
    return { success: false, error: err.message };
  }
}

// ─── Users Management ────────────────────────────────────────────────────────
export async function fetchUsersList() {
  try {
    // Collect admin emails to ensure administrators are never mixed into end-user client roster
    const adminEmails = new Set();
    if (DESIGNATED_ADMIN_EMAIL) {
      adminEmails.add(DESIGNATED_ADMIN_EMAIL.toLowerCase().trim());
    }

    try {
      const { data: adminRows } = await supabaseAdmin
        .from('admins')
        .select('email');
      if (adminRows) {
        adminRows.forEach(a => {
          if (a.email) adminEmails.add(a.email.toLowerCase().trim());
        });
      }
    } catch (_) {}

    const { data, error } = await supabaseAdmin
      .from('users')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) throw error;
    return (data || []).filter(u => !adminEmails.has(u.email?.toLowerCase().trim()));
  } catch (err) {
    console.error('Error fetching users:', err);
    return [];
  }
}

export async function updateUserRecord(uid, updates) {
  try {
    const { data, error } = await supabaseAdmin
      .from('users')
      .update(updates)
      .eq('uid', uid)
      .select()
      .single();

    if (error) throw error;
    return { success: true, data };
  } catch (err) {
    console.error('Error updating user:', err);
    return { success: false, error: err.message };
  }
}

export async function deleteUserRecord(uid) {
  try {
    // 1. Wipe all user-related data from all public database tables
    await Promise.allSettled([
      supabaseAdmin.from('users').delete().eq('uid', uid),
      supabaseAdmin.from('scan_history').delete().eq('user_id', uid),
      supabaseAdmin.from('scans').delete().eq('user_id', uid),
      supabaseAdmin.from('ai_usage').delete().eq('user_id', uid),
      supabaseAdmin.from('plants').delete().eq('user_id', uid),
      supabaseAdmin.from('farm_plots').delete().eq('user_id', uid),
      supabaseAdmin.from('admins').delete().eq('uid', uid)
    ]);

    // 2. Wipe from Supabase Auth (auth.users) so tokens & active sessions are instantly revoked
    try {
      await supabaseAdmin.auth.admin.deleteUser(uid);
    } catch (authErr) {
      console.warn('Auth admin delete user notice:', authErr.message);
    }

    return { success: true };
  } catch (err) {
    console.error('Error deleting user:', err);
    return { success: false, error: err.message };
  }
}

// ─── AI Usage Management ─────────────────────────────────────────────────────
export async function fetchAiUsageList() {
  try {
    const { data, error } = await supabaseAdmin
      .from('ai_usage')
      .select('*')
      .order('used_at', { ascending: false })
      .limit(100);

    if (error) throw error;
    return data || [];
  } catch (err) {
    console.error('Error fetching AI usage:', err);
    return [];
  }
}

// ─── Scans Management ────────────────────────────────────────────────────────
export async function fetchScansList() {
  try {
    const { data, error } = await supabaseAdmin
      .from('scans')
      .select('*')
      .order('scanned_at', { ascending: false });

    if (!error && data && data.length > 0) {
      return data;
    }

    const { data: shData, error: shError } = await supabaseAdmin
      .from('scan_history')
      .select('*')
      .order('scanned_at', { ascending: false });

    if (shError) throw shError;
    return shData || [];
  } catch (err) {
    console.error('Error fetching scans:', err);
    return [];
  }
}

// ─── Payments Management ─────────────────────────────────────────────────────
export async function fetchPaymentsList() {
  try {
    const { data, error } = await supabaseAdmin
      .from('payments')
      .select('*')
      .order('paid_at', { ascending: false });

    if (error) throw error;
    return data || [];
  } catch (err) {
    console.error('Error fetching payments:', err);
    return [];
  }
}

export async function updateAiUsageRecord(id, updates) {
  try {
    const { data, error } = await supabaseAdmin
      .from('ai_usage')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;
    return { success: true, data };
  } catch (err) {
    console.error('Error updating AI usage:', err);
    return { success: false, error: err.message };
  }
}

export async function resetUserDailyAi(userId) {
  try {
    const { data, error } = await supabaseAdmin
      .from('users')
      .update({ daily_ai_count: 0 })
      .eq('uid', userId)
      .select()
      .single();

    if (error) throw error;
    return { success: true, data };
  } catch (err) {
    console.error('Error resetting user daily AI:', err);
    return { success: false, error: err.message };
  }
}

// ─── Outbreaks & Retailers ───────────────────────────────────────────────────
export async function fetchOutbreaks() {
  try {
    const { data, error } = await supabaseAdmin.from('outbreak_alerts').select('*').limit(20);
    if (error) {
      console.error('fetchOutbreaks error with supabaseAdmin:', error);
      const { data: pubData, error: pubErr } = await supabase.from('outbreak_alerts').select('*').limit(20);
      if (pubErr) console.error('fetchOutbreaks error with supabase pub:', pubErr);
      return pubData || [];
    }
    return data || [];
  } catch (err) {
    console.error('fetchOutbreaks exception:', err);
    return [];
  }
}

export async function fetchRetailers() {
  try {
    const { data, error } = await supabaseAdmin.from('retailers').select('*').limit(20);
    if (error) {
      console.error('fetchRetailers error with supabaseAdmin:', error);
      const { data: pubData, error: pubErr } = await supabase.from('retailers').select('*').limit(20);
      if (pubErr) console.error('fetchRetailers error with supabase pub:', pubErr);
      return pubData || [];
    }
    return data || [];
  } catch (err) {
    console.error('fetchRetailers exception:', err);
    return [];
  }
}
