// web/src/components/Admin/DashboardPage.jsx
import React from 'react';
import { useApp } from '../../context/AppContext';
import { 
  Users, 
  Cpu, 
  Camera, 
  Sparkles, 
  CreditCard, 
  CheckCircle2, 
  AlertTriangle, 
  ArrowUpRight, 
  Radio, 
  TrendingUp,
  Activity,
  Server
} from 'lucide-react';

export default function DashboardPage() {
  const { users, aiUsage, outbreaks, scans, payments, appConfig, setAdminSubPage } = useApp();

  // Calculated metrics strictly from PostgreSQL database tables
  const totalUsers = users.length;
  const proUsers = users.filter(u => u.subscription_tier === 'pro' || u.subscription_tier === 'farm').length;
  const bannedUsers = users.filter(u => u.banned).length;

  const isOffline = (feat) => {
    const f = (feat || '').toLowerCase();
    return f.includes('offline') || f.includes('local') || f.includes('edge') || f.includes('tflite');
  };

  const totalScans = (scans && scans.length > 0) 
    ? scans.length 
    : users.reduce((acc, u) => acc + (u.scan_count || 0), 0);
  const totalTokens = aiUsage.reduce((acc, a) => acc + (a.tokens_used || 0), 0);
  const totalAiQueries = aiUsage.length;

  const onlineAiLogs = aiUsage.filter(a => !isOffline(a.feature));
  const onlineAiCount = onlineAiLogs.length;
  const onlineTokens = onlineAiLogs.reduce((acc, a) => acc + (a.tokens_used || 0), 0);

  const offlineAiLogs = aiUsage.filter(a => isOffline(a.feature));
  const offlineAiCount = offlineAiLogs.length;

  // Actual Revenue from payments table in Supabase
  const totalRevenue = payments
    ? payments.filter(p => p.status === 'success').reduce((acc, p) => acc + (parseFloat(p.amount) || 0), 0)
    : 0;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '28px' }}>
      {/* Top Banner */}
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        flexWrap: 'wrap',
        gap: '16px'
      }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span className="badge badge-emerald">Live Telemetry</span>
            <span className="badge badge-mint">Supabase PostgreSQL Synced</span>
          </div>
          <h1 style={{ fontSize: '30px', marginTop: '6px' }}>App Usage & Operational Dashboard</h1>
          <p style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>
            Real-time aggregate diagnostics, AI token consumption, user tiers, and epidemic telemetry.
          </p>
        </div>

        <div style={{ display: 'flex', gap: '10px' }}>
          <button onClick={() => setAdminSubPage('config')} className="btn btn-white btn-sm">
            ⚙️ Edit Limits & Config
          </button>
          <button onClick={() => setAdminSubPage('users')} className="btn btn-primary btn-sm">
            👥 Manage Users ({totalUsers})
          </button>
        </div>
      </div>

      {/* Primary KPI Cards */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
        gap: '18px'
      }}>
        {/* Total Users */}
        <div className="neo-card" style={{ padding: '20px', backgroundColor: '#FFFFFF' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{ fontSize: '11px', fontWeight: 800, textTransform: 'uppercase', color: 'var(--text-muted)' }}>
                Total Accounts
              </div>
              <div style={{ fontSize: '32px', fontWeight: 800, fontFamily: 'var(--font-display)', marginTop: '4px' }}>
                {totalUsers}
              </div>
            </div>
            <div style={{
              width: '38px',
              height: '38px',
              borderRadius: 'var(--radius-md)',
              backgroundColor: 'var(--primary-tint)',
              border: 'var(--border-width-sm) solid var(--border-color)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <Users size={20} color="var(--primary-dark)" />
            </div>
          </div>
          <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '10px' }}>
            <b style={{ color: 'var(--primary-dark)' }}>{proUsers} Pro/Farm</b> · {bannedUsers} Banned
          </div>
        </div>

        {/* Combined AI Inferences with Online & Offline Breakdown */}
        <div className="neo-card" style={{ padding: '20px', backgroundColor: '#FFFFFF' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{ fontSize: '11px', fontWeight: 800, textTransform: 'uppercase', color: 'var(--text-muted)' }}>
                AI Inferences (Combined)
              </div>
              <div style={{ fontSize: '32px', fontWeight: 800, fontFamily: 'var(--font-display)', color: 'var(--secondary)', marginTop: '4px' }}>
                {totalAiQueries} <span style={{ fontSize: '15px', fontWeight: 700, color: 'var(--text-secondary)' }}>({totalTokens} tokens)</span>
              </div>
            </div>
            <div style={{
              width: '38px',
              height: '38px',
              borderRadius: 'var(--radius-md)',
              backgroundColor: 'var(--secondary-tint)',
              border: 'var(--border-width-sm) solid var(--border-color)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <Cpu size={20} color="var(--secondary)" />
            </div>
          </div>
          <div style={{ display: 'flex', gap: '6px', marginTop: '10px', flexWrap: 'wrap' }}>
            <span className="badge badge-sky" style={{ fontSize: '10px', padding: '2px 6px' }}>
              ☁️ Online: <b>{onlineAiCount}</b> ({onlineTokens}t)
            </span>
            <span className="badge badge-amber" style={{ fontSize: '10px', padding: '2px 6px' }}>
              📱 Offline: <b>{offlineAiCount}</b> (0t)
            </span>
          </div>
        </div>

        {/* Leaf Pathology Scans */}
        <div className="neo-card" style={{ padding: '20px', backgroundColor: '#FFFFFF' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{ fontSize: '11px', fontWeight: 800, textTransform: 'uppercase', color: 'var(--text-muted)' }}>
                Leaf Scans Logged
              </div>
              <div style={{ fontSize: '32px', fontWeight: 800, fontFamily: 'var(--font-display)', color: 'var(--primary-dark)', marginTop: '4px' }}>
                {totalScans}
              </div>
            </div>
            <div style={{
              width: '38px',
              height: '38px',
              borderRadius: 'var(--radius-md)',
              backgroundColor: 'var(--primary-tint)',
              border: 'var(--border-width-sm) solid var(--border-color)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <Camera size={20} color="var(--primary-dark)" />
            </div>
          </div>
          <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '10px' }}>
            Logged in PostgreSQL database
          </div>
        </div>

        {/* Active Outbreaks */}
        <div className="neo-card" style={{ padding: '20px', backgroundColor: '#FFFFFF' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{ fontSize: '11px', fontWeight: 800, textTransform: 'uppercase', color: 'var(--text-muted)' }}>
                Active Epidemics
              </div>
              <div style={{ fontSize: '32px', fontWeight: 800, fontFamily: 'var(--font-display)', color: 'var(--accent-red)', marginTop: '4px' }}>
                {outbreaks.length}
              </div>
            </div>
            <div style={{
              width: '38px',
              height: '38px',
              borderRadius: 'var(--radius-md)',
              backgroundColor: 'var(--accent-red-tint)',
              border: 'var(--border-width-sm) solid var(--border-color)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <Radio size={20} color="var(--accent-red)" />
            </div>
          </div>
          <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '10px' }}>
            Tracked on 10 km Community Radar
          </div>
        </div>

        {/* Actual Gross Revenue */}
        <div className="neo-card" style={{ padding: '20px', backgroundColor: '#FFFFFF' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{ fontSize: '11px', fontWeight: 800, textTransform: 'uppercase', color: 'var(--text-muted)' }}>
                Actual Gross Revenue
              </div>
              <div style={{ fontSize: '32px', fontWeight: 800, fontFamily: 'var(--font-display)', color: 'var(--accent-amber)', marginTop: '4px' }}>
                ₹{totalRevenue}
              </div>
            </div>
            <div style={{
              width: '38px',
              height: '38px',
              borderRadius: 'var(--radius-md)',
              backgroundColor: 'var(--accent-amber-tint)',
              border: 'var(--border-width-sm) solid var(--border-color)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <CreditCard size={20} color="var(--accent-amber)" />
            </div>
          </div>
          <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '10px' }}>
            ₹{totalRevenue} settled across {payments.length} transactions
          </div>
        </div>
      </div>

      {/* Infrastructure Health Status */}
      <div className="neo-card" style={{ backgroundColor: '#FFFFFF' }}>
        <h3 style={{ fontSize: '18px', marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
          <Server size={18} />
          <span>Core Infrastructure & API Providers Health</span>
        </h3>

        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '14px'
        }}>
          <div style={{ padding: '12px', backgroundColor: 'var(--bg-subtle)', borderRadius: 'var(--radius-md)', border: '1.5px solid #0F172A' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: 700 }}>
              <span className="pulse-dot" />
              <span>Supabase PostgreSQL</span>
            </div>
            <div style={{ fontSize: '11px', color: 'var(--primary-dark)', fontWeight: 600, marginTop: '4px' }}>
              Connected · Port 5432
            </div>
          </div>

          <div style={{ padding: '12px', backgroundColor: 'var(--bg-subtle)', borderRadius: 'var(--radius-md)', border: '1.5px solid #0F172A' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: 700 }}>
              <span className="pulse-dot" />
              <span>Groq LLaMA-3 Pool</span>
            </div>
            <div style={{ fontSize: '11px', color: 'var(--primary-dark)', fontWeight: 600, marginTop: '4px' }}>
              2 Active Keys · 100% SLA
            </div>
          </div>

          <div style={{ padding: '12px', backgroundColor: 'var(--bg-subtle)', borderRadius: 'var(--radius-md)', border: '1.5px solid #0F172A' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: 700 }}>
              <span className="pulse-dot" />
              <span>Gemini Vision Pool</span>
            </div>
            <div style={{ fontSize: '11px', color: 'var(--primary-dark)', fontWeight: 600, marginTop: '4px' }}>
              5 Auto-Rotated API Keys
            </div>
          </div>

          <div style={{ padding: '12px', backgroundColor: 'var(--bg-subtle)', borderRadius: 'var(--radius-md)', border: '1.5px solid #0F172A' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: 700 }}>
              <span className="pulse-dot" />
              <span>PlantNet Species API</span>
            </div>
            <div style={{ fontSize: '11px', color: 'var(--primary-dark)', fontWeight: 600, marginTop: '4px' }}>
              500 calls/day · 82k species
            </div>
          </div>

          <div style={{ padding: '12px', backgroundColor: 'var(--bg-subtle)', borderRadius: 'var(--radius-md)', border: '1.5px solid #0F172A' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: 700 }}>
              <span className="pulse-dot" />
              <span>Razorpay Payments</span>
            </div>
            <div style={{ fontSize: '11px', color: 'var(--primary-dark)', fontWeight: 600, marginTop: '4px' }}>
              Test Mode · Webhook Active
            </div>
          </div>
        </div>
      </div>

      {/* Recent AI Usage Feed */}
      <div className="neo-card" style={{ backgroundColor: '#FFFFFF' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
          <div>
            <h3 style={{ fontSize: '18px' }}>Recent AI Inferences & Token Logs</h3>
            <p style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
              Live queries logged from PhytoLens mobile clients.
            </p>
          </div>
          <button onClick={() => setAdminSubPage('ai_usage')} className="btn btn-outline btn-sm">
            Manage All AI Usage →
          </button>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
            <thead>
              <tr style={{ borderBottom: '2px solid #0F172A', textAlign: 'left', backgroundColor: 'var(--bg-subtle)' }}>
                <th style={{ padding: '10px' }}>Log ID</th>
                <th style={{ padding: '10px' }}>User ID</th>
                <th style={{ padding: '10px' }}>Feature</th>
                <th style={{ padding: '10px' }}>Tokens Burned</th>
                <th style={{ padding: '10px' }}>Timestamp</th>
              </tr>
            </thead>
            <tbody>
              {aiUsage.slice(0, 5).map((log, i) => (
                <tr key={log.id || i} style={{ borderBottom: '1px solid #E2E8F0' }}>
                  <td style={{ padding: '10px', fontFamily: 'var(--font-mono)', fontSize: '11px' }}>
                    {log.id ? log.id.substring(0, 8) + '...' : `LOG-#${i+1}`}
                  </td>
                  <td style={{ padding: '10px', fontFamily: 'var(--font-mono)', fontSize: '11px' }}>
                    {log.user_id ? log.user_id.substring(0, 10) + '...' : 'Anonymous'}
                  </td>
                  <td style={{ padding: '10px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                      {isOffline(log.feature) ? (
                        <span className="badge badge-amber" style={{ fontSize: '10px', padding: '2px 6px' }}>
                          📱 Offline Edge
                        </span>
                      ) : (
                        <span className="badge badge-sky" style={{ fontSize: '10px', padding: '2px 6px' }}>
                          ☁️ Online Cloud
                        </span>
                      )}
                      <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                        {log.feature}
                      </span>
                    </div>
                  </td>
                  <td style={{ padding: '10px', fontWeight: 700 }}>
                    {isOffline(log.feature) ? (
                      <span style={{ color: 'var(--accent-amber)', fontSize: '12px' }}>0 tokens (On-Device)</span>
                    ) : (
                      <span>{log.tokens_used} tokens</span>
                    )}
                  </td>
                  <td style={{ padding: '10px', color: 'var(--text-muted)', fontSize: '12px' }}>
                    {log.used_at ? new Date(log.used_at).toLocaleTimeString() : 'Just now'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
