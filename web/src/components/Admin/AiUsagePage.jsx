// web/src/components/Admin/AiUsagePage.jsx
import React, { useState } from 'react';
import { useApp } from '../../context/AppContext';
import { 
  Cpu, 
  Search, 
  RotateCcw, 
  Edit3, 
  Save, 
  X, 
  CheckCircle, 
  Trash2, 
  Plus, 
  Sparkles,
  Filter,
  BarChart2,
  Cloud,
  Smartphone,
  Layers,
  Zap,
  TrendingDown
} from 'lucide-react';
import ConfirmModal from '../Common/ConfirmModal';

function isOfflineFeature(feature) {
  const f = (feature || '').toLowerCase();
  return f.includes('offline') || f.includes('local') || f.includes('edge') || f.includes('tflite');
}

export default function AiUsagePage() {
  const { 
    aiUsage, 
    users, 
    handleUpdateAiUsage, 
    handleResetUserAi, 
    handleUpdateUser, 
    showToast 
  } = useApp();

  const [searchQuery, setSearchQuery] = useState('');
  const [engineFilter, setEngineFilter] = useState('all'); // 'all' | 'online' | 'offline'
  const [featureFilter, setFeatureFilter] = useState('all');

  // Edit Modal State
  const [editingLog, setEditingLog] = useState(null);
  const [editingUserQuota, setEditingUserQuota] = useState(null);
  const [saving, setSaving] = useState(false);

  // Neobrutalism Confirmation Modal State
  const [confirmModal, setConfirmModal] = useState({
    isOpen: false,
    title: '',
    message: '',
    confirmText: 'Confirm',
    variant: 'warning',
    icon: null,
    onConfirm: () => {}
  });

  const closeConfirmModal = () => {
    setConfirmModal(prev => ({ ...prev, isOpen: false }));
  };

  // ── Telemetry Aggregates (Combined, Online, and Offline) ─────────────────────
  const totalInferences = aiUsage.length;
  const totalTokens = aiUsage.reduce((s, a) => s + (a.tokens_used || 0), 0);

  const onlineLogs = aiUsage.filter(a => !isOfflineFeature(a.feature));
  const onlineInferences = onlineLogs.length;
  const onlineTokens = onlineLogs.reduce((s, a) => s + (a.tokens_used || 0), 0);

  const offlineLogs = aiUsage.filter(a => isOfflineFeature(a.feature));
  const offlineInferences = offlineLogs.length;
  const offlineTokens = offlineLogs.reduce((s, a) => s + (a.tokens_used || 0), 0);

  const offlineRatio = totalInferences > 0 ? Math.round((offlineInferences / totalInferences) * 100) : 0;

  // Group AI usage by user with detailed Online & Offline breakdown
  const userAiStats = users.map(user => {
    const userLogs = aiUsage.filter(a => a.user_id === user.uid);
    const userOnlineLogs = userLogs.filter(a => !isOfflineFeature(a.feature));
    const userOfflineLogs = userLogs.filter(a => isOfflineFeature(a.feature));

    const uOnlineTokens = userOnlineLogs.reduce((sum, l) => sum + (l.tokens_used || 0), 0);
    const uOfflineTokens = userOfflineLogs.reduce((sum, l) => sum + (l.tokens_used || 0), 0);

    return {
      uid: user.uid,
      email: user.email,
      displayName: user.display_name,
      dailyAiCount: user.daily_ai_count || 0,
      combinedQueries: userLogs.length,
      combinedTokens: uOnlineTokens + uOfflineTokens,
      onlineQueries: userOnlineLogs.length,
      onlineTokens: uOnlineTokens,
      offlineQueries: userOfflineLogs.length,
      offlineTokens: uOfflineTokens,
      subscriptionTier: user.subscription_tier || 'free',
      lastAiDate: user.last_ai_date || 'N/A'
    };
  });

  // Filter raw inference logs
  const filteredLogs = aiUsage.filter(log => {
    const isOff = isOfflineFeature(log.feature);
    const matchesEngine = engineFilter === 'all' || 
      (engineFilter === 'offline' ? isOff : !isOff);

    const matchesFeature = featureFilter === 'all' || log.feature === featureFilter;

    const q = searchQuery.toLowerCase();
    const matchesSearch = !q || 
      (log.user_id && log.user_id.toLowerCase().includes(q)) ||
      (log.feature && log.feature.toLowerCase().includes(q));

    return matchesEngine && matchesFeature && matchesSearch;
  });

  // Save edited log entry
  const handleSaveLog = async (e) => {
    e.preventDefault();
    if (!editingLog || saving) return;
    setSaving(true);
    try {
      await handleUpdateAiUsage(editingLog.id, {
        tokens_used: parseInt(editingLog.tokens_used) || 0,
        feature: editingLog.feature
      });
      setEditingLog(null);
    } finally {
      setSaving(false);
    }
  };

  // Save edited user quota
  const handleSaveUserQuota = async (e) => {
    e.preventDefault();
    if (!editingUserQuota || saving) return;
    setSaving(true);
    try {
      await handleUpdateUser(editingUserQuota.uid, {
        daily_ai_count: parseInt(editingUserQuota.dailyAiCount) || 0
      });
      setEditingUserQuota(null);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '28px' }}>
      {/* Header */}
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        flexWrap: 'wrap',
        gap: '16px'
      }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span className="badge badge-sky">Online Cloud & Offline Edge</span>
            <span className="badge badge-emerald">Combined Telemetry</span>
          </div>
          <h1 style={{ fontSize: '30px', marginTop: '6px' }}>AI Usage & Token Management</h1>
          <p style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>
            Real-time analytics for online cloud inference (Groq/Gemini), offline edge compute (GGUF/TFLite), and combined quota governance.
          </p>
        </div>
      </div>

      {/* ─── Online vs Offline vs Combined Metrics Strip ──────────────────── */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))',
        gap: '16px'
      }}>
        {/* 1. Combined Total */}
        <div className="neo-card" style={{ padding: '20px', backgroundColor: '#FFFFFF' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{ fontSize: '11px', fontWeight: 800, textTransform: 'uppercase', color: 'var(--text-muted)' }}>
                Combined Inferences
              </div>
              <div style={{ fontSize: '30px', fontWeight: 800, fontFamily: 'var(--font-display)', marginTop: '4px' }}>
                {totalInferences} <span style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-secondary)' }}>calls</span>
              </div>
            </div>
            <div style={{
              width: '40px',
              height: '40px',
              borderRadius: 'var(--radius-md)',
              backgroundColor: 'var(--primary-tint)',
              border: '2px solid #0F172A',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <Layers size={20} color="var(--primary-dark)" />
            </div>
          </div>
          <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '10px' }}>
            Total <b>{totalTokens} tokens</b> burned across all users
          </div>
        </div>

        {/* 2. Online Cloud AI */}
        <div className="neo-card" style={{ padding: '20px', backgroundColor: '#FFFFFF' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{ fontSize: '11px', fontWeight: 800, textTransform: 'uppercase', color: 'var(--secondary)' }}>
                ☁️ Online Cloud AI
              </div>
              <div style={{ fontSize: '30px', fontWeight: 800, fontFamily: 'var(--font-display)', color: 'var(--secondary)', marginTop: '4px' }}>
                {onlineInferences} <span style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-secondary)' }}>queries</span>
              </div>
            </div>
            <div style={{
              width: '40px',
              height: '40px',
              borderRadius: 'var(--radius-md)',
              backgroundColor: 'var(--secondary-tint)',
              border: '2px solid #0F172A',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <Cloud size={20} color="var(--secondary)" />
            </div>
          </div>
          <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '10px' }}>
            <b>{onlineTokens} tokens burned</b> · Groq LLaMA-3.3 Cloud
          </div>
        </div>

        {/* 3. Offline Edge AI */}
        <div className="neo-card" style={{ padding: '20px', backgroundColor: '#FFFFFF' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{ fontSize: '11px', fontWeight: 800, textTransform: 'uppercase', color: 'var(--accent-amber)' }}>
                📱 Offline Edge AI
              </div>
              <div style={{ fontSize: '30px', fontWeight: 800, fontFamily: 'var(--font-display)', color: 'var(--accent-amber)', marginTop: '4px' }}>
                {offlineInferences} <span style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-secondary)' }}>queries</span>
              </div>
            </div>
            <div style={{
              width: '40px',
              height: '40px',
              borderRadius: 'var(--radius-md)',
              backgroundColor: 'var(--accent-amber-tint)',
              border: '2px solid #0F172A',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <Smartphone size={20} color="var(--accent-amber)" />
            </div>
          </div>
          <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '10px' }}>
            <b>0 tokens burned</b> · 100% On-Device GGUF/TFLite
          </div>
        </div>

        {/* 4. Efficiency / Edge Ratio */}
        <div className="neo-card" style={{ padding: '20px', backgroundColor: '#FFFFFF' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{ fontSize: '11px', fontWeight: 800, textTransform: 'uppercase', color: 'var(--text-muted)' }}>
                Edge Offload Share
              </div>
              <div style={{ fontSize: '30px', fontWeight: 800, fontFamily: 'var(--font-display)', color: '#047857', marginTop: '4px' }}>
                {offlineRatio}%
              </div>
            </div>
            <div style={{
              width: '40px',
              height: '40px',
              borderRadius: 'var(--radius-md)',
              backgroundColor: '#D1FAE5',
              border: '2px solid #0F172A',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <TrendingDown size={20} color="#047857" />
            </div>
          </div>
          <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '10px' }}>
            Queries resolved offline with <b>zero API cost</b>
          </div>
        </div>
      </div>

      {/* ─── Per-User AI Quotas & Telemetry Table (Manageable & Editable) ─── */}
      <div className="neo-card" style={{ backgroundColor: '#FFFFFF', padding: '24px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', flexWrap: 'wrap', gap: '12px' }}>
          <div>
            <h3 style={{ fontSize: '18px' }}>Per-User AI Quotas & Online/Offline Telemetry</h3>
            <p style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
              Adjust individual user quotas, view online vs offline usage breakdown, or reset daily chat counts.
            </p>
          </div>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
            <thead>
              <tr style={{ borderBottom: '2px solid #0F172A', textAlign: 'left', backgroundColor: 'var(--bg-subtle)' }}>
                <th style={{ padding: '12px' }}>User / Account</th>
                <th style={{ padding: '12px' }}>Tier</th>
                <th style={{ padding: '12px' }}>Combined Inferences</th>
                <th style={{ padding: '12px' }}>☁️ Online AI Usage</th>
                <th style={{ padding: '12px' }}>📱 Offline Edge AI</th>
                <th style={{ padding: '12px' }}>Today's Quota</th>
                <th style={{ padding: '12px', textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {userAiStats.map(u => (
                <tr key={u.uid} style={{ borderBottom: '1px solid #E2E8F0' }}>
                  {/* User info */}
                  <td style={{ padding: '12px' }}>
                    <div style={{ fontWeight: 700, fontSize: '14px' }}>{u.displayName || 'Unnamed User'}</div>
                    <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                      {u.email}
                    </div>
                  </td>

                  {/* Tier */}
                  <td style={{ padding: '12px' }}>
                    <span className={`badge ${u.subscriptionTier === 'pro' || u.subscriptionTier === 'farm' ? 'badge-emerald' : 'badge-amber'}`}>
                      {u.subscriptionTier.toUpperCase()}
                    </span>
                  </td>

                  {/* Combined Inferences */}
                  <td style={{ padding: '12px' }}>
                    <div style={{ fontWeight: 800, fontSize: '14px' }}>
                      {u.combinedQueries} queries
                    </div>
                    <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                      {u.combinedTokens} total tokens
                    </div>
                  </td>

                  {/* Online Cloud AI */}
                  <td style={{ padding: '12px' }}>
                    <div style={{ fontWeight: 700, color: 'var(--secondary)' }}>
                      {u.onlineQueries} queries
                    </div>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                      {u.onlineTokens} cloud tokens burned
                    </div>
                  </td>

                  {/* Offline Edge AI */}
                  <td style={{ padding: '12px' }}>
                    <div style={{ fontWeight: 700, color: 'var(--accent-amber)' }}>
                      {u.offlineQueries} queries
                    </div>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                      0 cloud tokens (Local)
                    </div>
                  </td>

                  {/* Today's Count */}
                  <td style={{ padding: '12px' }}>
                    <span style={{ fontWeight: 800, fontSize: '15px' }}>{u.dailyAiCount}</span>
                    <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}> used today</span>
                  </td>

                  {/* Actions */}
                  <td style={{ padding: '12px', textAlign: 'right' }}>
                    <div style={{ display: 'inline-flex', gap: '8px' }}>
                      <button
                        onClick={() => setEditingUserQuota({ ...u })}
                        className="btn btn-white btn-sm"
                        title="Edit Quota & Allowances"
                      >
                        <Edit3 size={13} />
                        <span>Edit</span>
                      </button>

                      <button
                        onClick={() => {
                          setConfirmModal({
                            isOpen: true,
                            title: "Reset Daily AI Usage Quota?",
                            message: `Reset today's AI chat queries counter for ${u.displayName || u.email} back to 0? This immediately grants fresh daily chat queries in real-time.`,
                            confirmText: "Reset Quota to 0",
                            variant: "warning",
                            icon: <RotateCcw size={24} color="#D97706" />,
                            onConfirm: async () => {
                              await handleResetUserAi(u.uid);
                            }
                          });
                        }}
                        className="btn btn-sm"
                        style={{ backgroundColor: 'var(--primary-tint)', color: 'var(--primary-dark)', borderColor: 'var(--border-color)' }}
                        title="Reset daily chat counter to 0"
                      >
                        <RotateCcw size={13} />
                        <span>Reset Today</span>
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* ─── Raw AI Inference Log Entries ─────────────────────────────────── */}
      <div className="neo-card" style={{ backgroundColor: '#FFFFFF', padding: '24px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px', flexWrap: 'wrap', gap: '12px' }}>
          <div>
            <h3 style={{ fontSize: '18px' }}>Individual AI Query Log Records</h3>
            <p style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
              Individual inference calls logged to Supabase `ai_usage`. Filter by execution engine or feature.
            </p>
          </div>

          {/* Engine Filter Pills */}
          <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', alignItems: 'center' }}>
            <div style={{ display: 'flex', gap: '6px' }}>
              <button
                onClick={() => setEngineFilter('all')}
                className={`btn btn-sm ${engineFilter === 'all' ? 'btn-primary' : 'btn-white'}`}
              >
                All Combined ({totalInferences})
              </button>
              <button
                onClick={() => setEngineFilter('online')}
                className={`btn btn-sm ${engineFilter === 'online' ? 'btn-primary' : 'btn-white'}`}
              >
                ☁️ Online Cloud ({onlineInferences})
              </button>
              <button
                onClick={() => setEngineFilter('offline')}
                className={`btn btn-sm ${engineFilter === 'offline' ? 'btn-primary' : 'btn-white'}`}
              >
                📱 Offline Edge ({offlineInferences})
              </button>
            </div>

            <div style={{ position: 'relative' }}>
              <Search size={14} style={{ position: 'absolute', left: '10px', top: '10px', color: 'var(--text-muted)' }} />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search logs..."
                className="neo-input"
                style={{ paddingLeft: '32px', paddingRight: '12px', height: '34px', fontSize: '12px', width: '160px' }}
              />
            </div>
          </div>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
            <thead>
              <tr style={{ borderBottom: '2px solid #0F172A', textAlign: 'left', backgroundColor: 'var(--bg-subtle)' }}>
                <th style={{ padding: '12px' }}>Log ID</th>
                <th style={{ padding: '12px' }}>Execution Engine</th>
                <th style={{ padding: '12px' }}>Feature Category</th>
                <th style={{ padding: '12px' }}>Tokens Burned</th>
                <th style={{ padding: '12px' }}>Timestamp</th>
                <th style={{ padding: '12px', textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredLogs.length === 0 ? (
                <tr>
                  <td colSpan={6} style={{ padding: '28px', textAlign: 'center', color: 'var(--text-muted)' }}>
                    No inference logs match the selected filter.
                  </td>
                </tr>
              ) : (
                filteredLogs.map(log => {
                  const isOff = isOfflineFeature(log.feature);
                  return (
                    <tr key={log.id} style={{ borderBottom: '1px solid #E2E8F0' }}>
                      <td style={{ padding: '12px', fontFamily: 'var(--font-mono)', fontSize: '11px' }}>
                        {log.id.substring(0, 8)}...
                      </td>

                      {/* Engine Badge */}
                      <td style={{ padding: '12px' }}>
                        {isOff ? (
                          <span className="badge badge-amber" style={{ fontSize: '10px', display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                            <Smartphone size={11} />
                            <span>OFFLINE EDGE</span>
                          </span>
                        ) : (
                          <span className="badge badge-sky" style={{ fontSize: '10px', display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                            <Cloud size={11} />
                            <span>ONLINE CLOUD</span>
                          </span>
                        )}
                      </td>

                      {/* Feature */}
                      <td style={{ padding: '12px' }}>
                        <span className="badge badge-dark" style={{ fontSize: '11px', textTransform: 'lowercase' }}>
                          {log.feature}
                        </span>
                      </td>

                      {/* Tokens */}
                      <td style={{ padding: '12px', fontWeight: 700 }}>
                        {isOff ? (
                          <span style={{ color: 'var(--accent-amber)', fontSize: '12px' }}>
                            0 tokens <span style={{ fontWeight: 400, color: 'var(--text-muted)' }}>(On-Device)</span>
                          </span>
                        ) : (
                          <span style={{ color: 'var(--secondary)' }}>
                            {log.tokens_used} tokens
                          </span>
                        )}
                      </td>

                      {/* Timestamp */}
                      <td style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '12px' }}>
                        {new Date(log.used_at).toLocaleString()}
                      </td>

                      {/* Actions */}
                      <td style={{ padding: '12px', textAlign: 'right' }}>
                        <button
                          onClick={() => setEditingLog({ ...log })}
                          className="btn btn-white btn-sm"
                          style={{ padding: '4px 8px', fontSize: '11px' }}
                        >
                          <Edit3 size={12} />
                          <span>Edit</span>
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ─── Edit User AI Quota Modal ─────────────────────────────────────── */}
      {editingUserQuota && (
        <div className="modal-overlay" onClick={() => !saving && setEditingUserQuota(null)}>
          <div className="neo-card" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '440px', width: '100%', backgroundColor: '#FFFFFF', padding: '24px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
              <div>
                <h3 style={{ fontSize: '18px' }}>Edit User AI Quota</h3>
                <p style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                  User: {editingUserQuota.email}
                </p>
              </div>
              <button 
                onClick={() => !saving && setEditingUserQuota(null)} 
                disabled={saving}
                style={{ background: 'none', border: 'none', cursor: saving ? 'not-allowed' : 'pointer' }}
              >
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleSaveUserQuota} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                  Today's AI Chats Used
                </label>
                <input
                  type="number"
                  min="0"
                  value={editingUserQuota.dailyAiCount}
                  onChange={(e) => setEditingUserQuota(prev => ({ ...prev, dailyAiCount: e.target.value }))}
                  className="neo-input"
                />
              </div>

              <div style={{ display: 'flex', gap: '10px', marginTop: '6px' }}>
                <button
                  type="button"
                  disabled={saving}
                  onClick={() => setEditingUserQuota(prev => ({ ...prev, dailyAiCount: 0 }))}
                  className="btn btn-white btn-sm"
                  style={{ flex: 1 }}
                >
                  Set to 0 (Reset)
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="btn btn-primary btn-sm"
                  style={{ flex: 1, opacity: saving ? 0.7 : 1, cursor: saving ? 'not-allowed' : 'pointer' }}
                >
                  <Save size={14} />
                  <span>{saving ? 'Saving...' : 'Save to Supabase'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ─── Edit Individual Log Modal ────────────────────────────────────── */}
      {editingLog && (
        <div className="modal-overlay" onClick={() => !saving && setEditingLog(null)}>
          <div className="neo-card" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '440px', width: '100%', backgroundColor: '#FFFFFF', padding: '24px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
              <h3 style={{ fontSize: '18px' }}>Edit AI Log Record</h3>
              <button 
                onClick={() => !saving && setEditingLog(null)} 
                disabled={saving}
                style={{ background: 'none', border: 'none', cursor: saving ? 'not-allowed' : 'pointer' }}
              >
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleSaveLog} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                  Tokens Burned
                </label>
                <input
                  type="number"
                  min="0"
                  value={editingLog.tokens_used}
                  onChange={(e) => setEditingLog(prev => ({ ...prev, tokens_used: e.target.value }))}
                  className="neo-input"
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                  Feature Category
                </label>
                <select
                  value={editingLog.feature}
                  onChange={(e) => setEditingLog(prev => ({ ...prev, feature: e.target.value }))}
                  className="neo-input neo-select"
                >
                  <option value="chatbot">chatbot (Online Cloud)</option>
                  <option value="chatbot_offline">chatbot_offline (Offline Edge)</option>
                  <option value="vision">vision (Online Cloud)</option>
                  <option value="remedy">remedy (Online Cloud)</option>
                </select>
              </div>

              <button
                type="submit"
                disabled={saving}
                className="btn btn-primary"
                style={{ width: '100%', marginTop: '8px', opacity: saving ? 0.7 : 1, cursor: saving ? 'not-allowed' : 'pointer' }}
              >
                <Save size={16} />
                <span>{saving ? 'Saving...' : 'Save Changes'}</span>
              </button>
            </form>
          </div>
        </div>
      )}

      {/* ─── Neobrutalism Confirmation Modal ─────────────────────────────── */}
      <ConfirmModal
        isOpen={confirmModal.isOpen}
        title={confirmModal.title}
        message={confirmModal.message}
        confirmText={confirmModal.confirmText}
        variant={confirmModal.variant}
        icon={confirmModal.icon}
        onConfirm={confirmModal.onConfirm}
        onClose={closeConfirmModal}
      />
    </div>
  );
}
