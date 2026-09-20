// web/src/components/Admin/UserManagementPage.jsx
import React, { useState } from 'react';
import { useApp } from '../../context/AppContext';
import { 
  Users, 
  Search, 
  UserCheck, 
  UserX, 
  Edit, 
  Trash2, 
  Shield, 
  Sparkles, 
  Award, 
  X, 
  Save, 
  Plus, 
  Phone, 
  MapPin,
  Calendar,
  AlertCircle
} from 'lucide-react';
import ConfirmModal from '../Common/ConfirmModal';

function UserAvatar({ url, name, size = 36 }) {
  const [hasError, setHasError] = useState(false);
  const initials = (name || '?')[0].toUpperCase();

  return (
    <div style={{
      width: `${size}px`,
      height: `${size}px`,
      borderRadius: '50%',
      border: '2px solid #0F172A',
      backgroundColor: 'var(--primary-tint)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontWeight: 800,
      fontSize: `${Math.round(size * 0.42)}px`,
      color: 'var(--primary-dark)',
      overflow: 'hidden',
      flexShrink: 0
    }}>
      {url && !hasError ? (
        <img
          src={url}
          alt=""
          referrerPolicy="no-referrer"
          crossOrigin="anonymous"
          onError={() => setHasError(true)}
          style={{ width: '100%', height: '100%', objectFit: 'cover' }}
        />
      ) : (
        <span>{initials}</span>
      )}
    </div>
  );
}

export default function UserManagementPage() {
  const { users, handleUpdateUser, handleDeleteUser, showToast } = useApp();
  const [searchQuery, setSearchQuery] = useState('');
  const [tierFilter, setTierFilter] = useState('all');

  // Edit Modal State
  const [selectedUser, setSelectedUser] = useState(null);
  const [saving, setSaving] = useState(false);

  // Neobrutalism Confirmation Modal State
  const [confirmModal, setConfirmModal] = useState({
    isOpen: false,
    title: '',
    message: '',
    confirmText: 'Confirm',
    variant: 'danger',
    icon: null,
    onConfirm: () => {}
  });

  const closeConfirmModal = () => {
    setConfirmModal(prev => ({ ...prev, isOpen: false }));
  };

  // Filter users
  const filteredUsers = users.filter(u => {
    const q = searchQuery.toLowerCase();
    const matchesSearch = !q || 
      (u.email && u.email.toLowerCase().includes(q)) ||
      (u.display_name && u.display_name.toLowerCase().includes(q));

    const matchesTier = tierFilter === 'all' || 
      (tierFilter === 'banned' ? u.banned : u.subscription_tier === tierFilter);

    return matchesSearch && matchesTier;
  });

  const handleEditClick = (user) => {
    setSelectedUser({ ...user });
  };

  const handleSaveUser = async (e) => {
    e.preventDefault();
    if (!selectedUser || saving) return;
    setSaving(true);

    try {
      const updates = {
        display_name: selectedUser.display_name,
        subscription_tier: selectedUser.subscription_tier,
        banned: selectedUser.banned,
        level: parseInt(selectedUser.level) || 1,
        xp: parseInt(selectedUser.xp) || 0,
        streak: parseInt(selectedUser.streak) || 0,
        scan_count: parseInt(selectedUser.scan_count) || 0,
        daily_scan_count: parseInt(selectedUser.daily_scan_count) || 0,
        daily_ai_count: parseInt(selectedUser.daily_ai_count) || 0,
        phone: selectedUser.phone || null,
        location: selectedUser.location || null,
        garden_type: selectedUser.garden_type || null
      };

      const success = await handleUpdateUser(selectedUser.uid, updates);
      if (success) {
        setSelectedUser(null);
      }
    } finally {
      setSaving(false);
    }
  };

  // Neobrutalism Action Triggers
  const triggerBanToggle = (user) => {
    const isBanning = !user.banned;
    setConfirmModal({
      isOpen: true,
      title: isBanning ? 'Suspend User Account?' : 'Restore User Access?',
      message: isBanning 
        ? `Are you sure you want to ban ${user.display_name || user.email}? This will immediately push a real-time lockdown ban screen to their mobile device.`
        : `Unban ${user.display_name || user.email}? The ban screen will automatically dismiss on their mobile device and restore full access.`,
      confirmText: isBanning ? 'Ban Account' : 'Unban Account',
      variant: isBanning ? 'danger' : 'emerald',
      icon: isBanning ? <UserX size={24} color="#EF4444" /> : <UserCheck size={24} color="#10B981" />,
      onConfirm: async () => {
        await handleUpdateUser(user.uid, { banned: isBanning });
        showToast(isBanning ? `User ${user.email} banned.` : `User ${user.email} unbanned.`);
      }
    });
  };

  const triggerUpgradePro = (user) => {
    setConfirmModal({
      isOpen: true,
      title: 'Upgrade Account to Pro Tier?',
      message: `Promote ${user.display_name || user.email} to Pro Tier? This immediately activates 50 daily scans, 50 daily AI queries, and premium offline capabilities for 30 days.`,
      confirmText: 'Upgrade to Pro Tier',
      variant: 'primary',
      icon: <Sparkles size={24} color="var(--primary-dark)" />,
      onConfirm: async () => {
        await handleUpdateUser(user.uid, { 
          subscription_tier: 'pro',
          subscription_expiry: new Date(Date.now() + 30 * 86400000).toISOString()
        });
        showToast(`Upgraded ${user.email} to Pro Tier! ⚡`);
      }
    });
  };

  const triggerDeleteUser = (user) => {
    setConfirmModal({
      isOpen: true,
      title: 'Permanently Delete User Account?',
      message: (
        <div>
          <p style={{ marginBottom: '10px' }}>
            Are you sure you want to completely erase <strong>{user.display_name || user.email}</strong>?
          </p>
          <div style={{
            backgroundColor: '#FEE2E2',
            padding: '12px',
            borderRadius: '8px',
            border: '1.5px solid #EF4444',
            fontSize: '12px',
            color: '#991B1B',
            lineHeight: 1.5
          }}>
            <strong>⚠️ Irreversible Database Wipeout:</strong> This completely purges all user rows, leaf scans, farm plots, and AI logs from Supabase tables AND permanently deletes the user from Supabase Auth. Any active mobile sessions will be force logged out immediately.
          </div>
        </div>
      ),
      confirmText: 'Permanently Delete User',
      variant: 'danger',
      icon: <Trash2 size={24} color="#EF4444" />,
      onConfirm: async () => {
        await handleDeleteUser(user.uid);
      }
    });
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
            <span className="badge badge-emerald">User Roster & Credentials</span>
            <span className="badge badge-sky">Full Database CRUD</span>
          </div>
          <h1 style={{ fontSize: '30px', marginTop: '6px' }}>Manage All Users Fully</h1>
          <p style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>
            Search, inspect profile telemetry, edit subscription tiers, adjust quotas, and ban/unban accounts with real-time Supabase sync.
          </p>
        </div>
      </div>

      {/* Filter & Search Bar */}
      <div className="neo-card" style={{ padding: '16px', backgroundColor: '#FFFFFF' }}>
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: '12px'
        }}>
          {/* Search Input */}
          <div style={{ position: 'relative', flex: 1, minWidth: '260px' }}>
            <Search size={16} style={{ position: 'absolute', left: '12px', top: '12px', color: 'var(--text-muted)' }} />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search by name or email..."
              className="neo-input"
              style={{ paddingLeft: '38px' }}
            />
          </div>

          {/* Tier Filter Pills */}
          <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
            {['all', 'free', 'pro', 'farm', 'banned'].map(t => (
              <button
                key={t}
                onClick={() => setTierFilter(t)}
                className={`btn btn-sm ${tierFilter === t ? 'btn-primary' : 'btn-white'}`}
                style={{ textTransform: 'capitalize' }}
              >
                {t === 'all' ? `All (${users.length})` : t}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Users Table */}
      <div className="neo-card" style={{ backgroundColor: '#FFFFFF', padding: '0', overflow: 'hidden' }}>
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
            <thead>
              <tr style={{ borderBottom: '2px solid #0F172A', textAlign: 'left', backgroundColor: 'var(--bg-subtle)' }}>
                <th style={{ padding: '14px 16px' }}>User Details</th>
                <th style={{ padding: '14px 16px' }}>Subscription Tier</th>
                <th style={{ padding: '14px 16px' }}>Level & XP</th>
                <th style={{ padding: '14px 16px' }}>Daily Quotas (Scan / AI)</th>
                <th style={{ padding: '14px 16px' }}>Status</th>
                <th style={{ padding: '14px 16px', textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredUsers.length === 0 ? (
                <tr>
                  <td colSpan={6} style={{ padding: '36px', textAlign: 'center', color: 'var(--text-muted)' }}>
                    No users matching the filter criteria.
                  </td>
                </tr>
              ) : (
                filteredUsers.map(u => (
                  <tr key={u.uid} style={{ borderBottom: '1px solid #E2E8F0' }}>
                    {/* User info */}
                    <td style={{ padding: '14px 16px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <UserAvatar url={u.avatar_url} name={u.display_name || u.email} size={38} />
                        <div>
                          <div style={{ fontWeight: 800, fontSize: '14px' }}>
                            {u.display_name || 'Unnamed Grower'}
                          </div>
                          <div style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                            {u.email}
                          </div>
                        </div>
                      </div>
                    </td>

                    {/* Tier */}
                    <td style={{ padding: '14px 16px' }}>
                      <span className={`badge ${
                        u.subscription_tier === 'farm' ? 'badge-amber' : 
                        u.subscription_tier === 'pro' ? 'badge-emerald' : 'badge-sky'
                      }`}>
                        {u.subscription_tier ? u.subscription_tier.toUpperCase() : 'FREE'}
                      </span>
                      {u.subscription_expiry && (
                        <div style={{ fontSize: '10px', color: 'var(--text-muted)', marginTop: '4px' }}>
                          Expires: {new Date(u.subscription_expiry).toLocaleDateString()}
                        </div>
                      )}
                    </td>

                    {/* Level & XP */}
                    <td style={{ padding: '14px 16px' }}>
                      <div style={{ fontWeight: 700 }}>Level {u.level || 1}</div>
                      <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                        {u.xp || 0} XP · {u.streak || 0}d streak
                      </div>
                    </td>

                    {/* Daily Quotas */}
                    <td style={{ padding: '14px 16px' }}>
                      <div>
                        <b>{u.daily_scan_count || 0}</b> scans today ({u.scan_count || 0} total)
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--secondary)' }}>
                        <b>{u.daily_ai_count || 0}</b> AI queries today
                      </div>
                    </td>

                    {/* Status */}
                    <td style={{ padding: '14px 16px' }}>
                      {u.banned ? (
                        <span className="badge badge-red">BANNED</span>
                      ) : (
                        <span className="badge badge-emerald">ACTIVE</span>
                      )}
                    </td>

                    {/* Actions */}
                    <td style={{ padding: '14px 16px', textAlign: 'right' }}>
                      <div style={{ display: 'inline-flex', gap: '6px' }}>
                        <button
                          onClick={() => handleEditClick(u)}
                          className="btn btn-white btn-sm"
                          title="Full Edit User Modal"
                        >
                          <Edit size={13} />
                          <span>Edit</span>
                        </button>

                        {u.subscription_tier === 'free' && (
                          <button
                            onClick={() => triggerUpgradePro(u)}
                            className="btn btn-primary btn-sm"
                            title="Quick Upgrade to Pro"
                          >
                            <span>+Pro</span>
                          </button>
                        )}

                        <button
                          onClick={() => triggerBanToggle(u)}
                          className={`btn btn-sm ${u.banned ? 'btn-white' : ''}`}
                          style={{
                            backgroundColor: u.banned ? '#FFFFFF' : 'var(--accent-red-tint)',
                            color: u.banned ? 'var(--primary-dark)' : 'var(--accent-red)',
                            borderColor: u.banned ? 'var(--border-color)' : 'var(--accent-red)'
                          }}
                          title={u.banned ? 'Unban user and allow them to continue' : 'Ban user and show lockdown ban screen'}
                        >
                          {u.banned ? <UserCheck size={13} /> : <UserX size={13} />}
                          <span>{u.banned ? 'Unban' : 'Ban'}</span>
                        </button>

                        <button
                          onClick={() => triggerDeleteUser(u)}
                          className="btn btn-white btn-sm"
                          style={{ color: 'var(--accent-red)', borderColor: 'var(--accent-red)' }}
                          title="Completely wipe user from Supabase and auto-logout"
                        >
                          <Trash2 size={13} />
                          <span>Delete</span>
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ─── Full Edit User Modal ─────────────────────────────────────────── */}
      {selectedUser && (
        <div className="modal-overlay" onClick={() => !saving && setSelectedUser(null)}>
          <div 
            className="neo-card" 
            onClick={(e) => e.stopPropagation()} 
            style={{
              maxWidth: '560px',
              width: '100%',
              maxHeight: '90vh',
              overflowY: 'auto',
              backgroundColor: '#FFFFFF',
              padding: '24px'
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <UserAvatar url={selectedUser.avatar_url} name={selectedUser.display_name || selectedUser.email} size={42} />
                <div>
                  <h3 style={{ fontSize: '20px' }}>Full User Editor</h3>
                  <p style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                    Editing: {selectedUser.email}
                  </p>
                </div>
              </div>
              <button 
                onClick={() => !saving && setSelectedUser(null)} 
                disabled={saving}
                style={{ background: 'none', border: 'none', cursor: saving ? 'not-allowed' : 'pointer' }}
              >
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleSaveUser} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                    Display Name
                  </label>
                  <input
                    type="text"
                    value={selectedUser.display_name || ''}
                    onChange={(e) => setSelectedUser(prev => ({ ...prev, display_name: e.target.value }))}
                    className="neo-input"
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                    Email Address
                  </label>
                  <input
                    type="email"
                    disabled
                    value={selectedUser.email || ''}
                    className="neo-input"
                    style={{ backgroundColor: 'var(--bg-subtle)' }}
                  />
                </div>
              </div>

              {/* Tier & Ban */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                    Subscription Tier
                  </label>
                  <select
                    value={selectedUser.subscription_tier || 'free'}
                    onChange={(e) => setSelectedUser(prev => ({ ...prev, subscription_tier: e.target.value }))}
                    className="neo-input neo-select"
                  >
                    <option value="free">FREE</option>
                    <option value="pro">PRO (₹49)</option>
                    <option value="farm">FARM PACK (₹199)</option>
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                    Account Status
                  </label>
                  <select
                    value={selectedUser.banned ? 'banned' : 'active'}
                    onChange={(e) => setSelectedUser(prev => ({ ...prev, banned: e.target.value === 'banned' }))}
                    className="neo-input neo-select"
                  >
                    <option value="active">Active (Normal Access)</option>
                    <option value="banned">Banned (Locked Out)</option>
                  </select>
                </div>
              </div>

              {/* Level, XP, Streak */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                    Level (1–10)
                  </label>
                  <input
                    type="number"
                    min="1"
                    max="10"
                    value={selectedUser.level ?? 1}
                    onChange={(e) => setSelectedUser(prev => ({ ...prev, level: e.target.value }))}
                    className="neo-input"
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                    XP Points
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={selectedUser.xp ?? 0}
                    onChange={(e) => setSelectedUser(prev => ({ ...prev, xp: e.target.value }))}
                    className="neo-input"
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                    Daily Streak
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={selectedUser.streak ?? 0}
                    onChange={(e) => setSelectedUser(prev => ({ ...prev, streak: e.target.value }))}
                    className="neo-input"
                  />
                </div>
              </div>

              {/* Daily Quotas */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                    Today's Scan Count
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={selectedUser.daily_scan_count ?? 0}
                    onChange={(e) => setSelectedUser(prev => ({ ...prev, daily_scan_count: e.target.value }))}
                    className="neo-input"
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                    Today's AI Chat Count
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={selectedUser.daily_ai_count ?? 0}
                    onChange={(e) => setSelectedUser(prev => ({ ...prev, daily_ai_count: e.target.value }))}
                    className="neo-input"
                  />
                </div>
              </div>

              {/* Profile Details */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                    Phone Number
                  </label>
                  <input
                    type="text"
                    value={selectedUser.phone || ''}
                    placeholder="+91 98765 43210"
                    onChange={(e) => setSelectedUser(prev => ({ ...prev, phone: e.target.value }))}
                    className="neo-input"
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                    Location / Village
                  </label>
                  <input
                    type="text"
                    value={selectedUser.location || ''}
                    placeholder="e.g. Nashik, Maharashtra"
                    onChange={(e) => setSelectedUser(prev => ({ ...prev, location: e.target.value }))}
                    className="neo-input"
                  />
                </div>
              </div>

              <div style={{ display: 'flex', gap: '10px', marginTop: '12px' }}>
                <button
                  type="button"
                  disabled={saving}
                  onClick={() => setSelectedUser(null)}
                  className="btn btn-white btn-sm"
                  style={{ flex: 1, opacity: saving ? 0.6 : 1 }}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="btn btn-primary btn-sm"
                  style={{ flex: 2, fontWeight: 800, opacity: saving ? 0.7 : 1, cursor: saving ? 'not-allowed' : 'pointer' }}
                >
                  <Save size={16} />
                  <span>{saving ? 'Saving Updates...' : 'Save Updates to Supabase'}</span>
                </button>
              </div>
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
