// web/src/components/Admin/AppConfigPage.jsx
import React, { useState, useEffect } from 'react';
import { useApp } from '../../context/AppContext';
import { Save, RotateCcw, Sliders, CheckCircle2, ShieldAlert, Zap, DollarSign, Database, AlertTriangle } from 'lucide-react';
import ConfirmModal from '../Common/ConfirmModal';

export default function AppConfigPage() {
  const { appConfig, handleSaveAppConfig, showToast } = useApp();
  const [formData, setFormData] = useState({});
  const [saving, setSaving] = useState(false);

  // Neobrutalism Confirmation Modal State
  const [confirmModal, setConfirmModal] = useState({
    isOpen: false,
    title: '',
    message: '',
    confirmText: 'Confirm',
    variant: 'primary',
    icon: null,
    onConfirm: () => {}
  });

  const closeConfirmModal = () => {
    setConfirmModal(prev => ({ ...prev, isOpen: false }));
  };

  useEffect(() => {
    if (appConfig) {
      setFormData({ ...appConfig });
    }
  }, [appConfig]);

  const handleChange = (field, val) => {
    setFormData(prev => ({ ...prev, [field]: val }));
  };

  const handleToggle = (field) => {
    setFormData(prev => ({ ...prev, [field]: !prev[field] }));
  };

  const triggerSaveConfirm = (e) => {
    e.preventDefault();
    if (saving) return;

    const isLockdown = !!formData.maintenance_mode;

    setConfirmModal({
      isOpen: true,
      title: isLockdown ? '⚠️ Enable Emergency Maintenance Mode?' : 'Save System Configuration?',
      message: isLockdown ? (
        <div>
          <p style={{ marginBottom: '8px' }}>
            You are about to save the system configuration with <strong>Emergency Maintenance Mode ENABLED</strong>.
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
            <strong>Alert:</strong> All active PhytoLens mobile apps will immediately freeze and display the full-screen Maintenance Lockdown screen until you disable this setting.
          </div>
        </div>
      ) : (
        'Are you sure you want to persist these configuration changes to Supabase PostgreSQL? All mobile app clients will receive and apply updated quotas and parameters in real time.'
      ),
      confirmText: isLockdown ? 'Activate Lockdown & Save' : 'Save Configuration',
      variant: isLockdown ? 'danger' : 'primary',
      icon: isLockdown ? <ShieldAlert size={24} color="#EF4444" /> : <Save size={24} color="var(--primary-dark)" />,
      onConfirm: async () => {
        setSaving(true);
        try {
          await handleSaveAppConfig(formData);
        } finally {
          setSaving(false);
        }
      }
    });
  };

  const triggerResetDefaultsConfirm = () => {
    setConfirmModal({
      isOpen: true,
      title: 'Reset Configuration to Factory Defaults?',
      message: 'This will reset all daily quotas, subscription pricing, and feature toggles on this form to standard baseline values. You must click Save to persist them to the database.',
      confirmText: 'Reset Defaults',
      variant: 'warning',
      icon: <RotateCcw size={24} color="#D97706" />,
      onConfirm: () => {
        const defaults = {
          free_tier_days: 2,
          free_daily_scan_limit: 15,
          pro_daily_scan_limit: 50,
          farm_daily_scan_limit: 100,
          free_daily_ai_limit: 15,
          pro_daily_ai_limit: 50,
          farm_daily_ai_limit: 100,
          pro_monthly_price: 49,
          farm_monthly_price: 199,
          trial_price: 1,
          trial_days: 2,
          trial_enabled: true,
          garden_enabled: true,
          bulk_export_enabled: true,
          maintenance_mode: false,
          latest_version: '1.0.1'
        };
        setFormData(prev => ({ ...prev, ...defaults }));
        showToast('Reset form to factory defaults. Click Save to persist.');
      }
    });
  };

  return (
    <form onSubmit={triggerSaveConfirm} style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      {/* Top Section Header */}
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        flexWrap: 'wrap',
        gap: '16px'
      }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span className="badge badge-emerald">Global App Parameters</span>
            <span className="badge badge-amber">Instant Mobile Sync</span>
          </div>
          <h1 style={{ fontSize: '30px', marginTop: '6px' }}>App Configuration (`app_config`)</h1>
          <p style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>
            Configure daily quotas, subscription tier prices, trial duration, and feature toggles synced live with Supabase PostgreSQL.
          </p>
        </div>

        <div style={{ display: 'flex', gap: '10px' }}>
          <button
            type="button"
            disabled={saving}
            onClick={triggerResetDefaultsConfirm}
            className="btn btn-white btn-sm"
          >
            <RotateCcw size={14} />
            <span>Reset Defaults</span>
          </button>

          <button
            type="submit"
            disabled={saving}
            className="btn btn-primary btn-sm"
            style={{ fontWeight: 800, opacity: saving ? 0.7 : 1, cursor: saving ? 'not-allowed' : 'pointer' }}
          >
            <Save size={16} />
            <span>{saving ? 'Saving to Database...' : 'Save Changes to Supabase'}</span>
          </button>
        </div>
      </div>

      {/* Grid of Config Sections */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
        gap: '20px'
      }}>
        {/* Daily Scan Limits Card */}
        <div className="neo-card" style={{ backgroundColor: '#FFFFFF' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '16px' }}>
            <span style={{ fontSize: '22px' }}>📷</span>
            <h3 style={{ fontSize: '18px' }}>Daily Leaf Scan Limits</h3>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                Free Tier Daily Scans (per day)
              </label>
              <input
                type="number"
                min="0"
                max="500"
                value={formData.free_daily_scan_limit ?? 15}
                onChange={(e) => handleChange('free_daily_scan_limit', parseInt(e.target.value) || 0)}
                className="neo-input"
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                Pro Plan Daily Scans (per day)
              </label>
              <input
                type="number"
                min="0"
                max="500"
                value={formData.pro_daily_scan_limit ?? 50}
                onChange={(e) => handleChange('pro_daily_scan_limit', parseInt(e.target.value) || 0)}
                className="neo-input"
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                Farm Pack Daily Scans (per day, 0 = unlimited)
              </label>
              <input
                type="number"
                min="0"
                max="1000"
                value={formData.farm_daily_scan_limit ?? 100}
                onChange={(e) => handleChange('farm_daily_scan_limit', parseInt(e.target.value) || 0)}
                className="neo-input"
              />
            </div>
          </div>
        </div>

        {/* Daily AI Chat Limits Card */}
        <div className="neo-card" style={{ backgroundColor: '#FFFFFF' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '16px' }}>
            <span style={{ fontSize: '22px' }}>🤖</span>
            <h3 style={{ fontSize: '18px' }}>Daily Botanist AI Chat Limits</h3>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                Free Tier AI Chats (per day)
              </label>
              <input
                type="number"
                min="0"
                max="200"
                value={formData.free_daily_ai_limit ?? 15}
                onChange={(e) => handleChange('free_daily_ai_limit', parseInt(e.target.value) || 0)}
                className="neo-input"
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                Pro Plan AI Chats (per day)
              </label>
              <input
                type="number"
                min="0"
                max="500"
                value={formData.pro_daily_ai_limit ?? 50}
                onChange={(e) => handleChange('pro_daily_ai_limit', parseInt(e.target.value) || 0)}
                className="neo-input"
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                Farm Pack AI Chats (per day)
              </label>
              <input
                type="number"
                min="0"
                max="1000"
                value={formData.farm_daily_ai_limit ?? 100}
                onChange={(e) => handleChange('farm_daily_ai_limit', parseInt(e.target.value) || 0)}
                className="neo-input"
              />
            </div>
          </div>
        </div>

        {/* Pricing & Trial Tiers Card */}
        <div className="neo-card" style={{ backgroundColor: '#FFFFFF' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '16px' }}>
            <span style={{ fontSize: '22px' }}>💳</span>
            <h3 style={{ fontSize: '18px' }}>Subscription Pricing & Trial</h3>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                Pro Plan Monthly Price (₹ INR)
              </label>
              <input
                type="number"
                min="1"
                value={formData.pro_monthly_price ?? 49}
                onChange={(e) => handleChange('pro_monthly_price', parseInt(e.target.value) || 0)}
                className="neo-input"
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                Farm Pack Monthly Price (₹ INR)
              </label>
              <input
                type="number"
                min="1"
                value={formData.farm_monthly_price ?? 199}
                onChange={(e) => handleChange('farm_monthly_price', parseInt(e.target.value) || 0)}
                className="neo-input"
              />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                  Trial Price (₹)
                </label>
                <input
                  type="number"
                  step="0.1"
                  value={formData.trial_price ?? 1.0}
                  onChange={(e) => handleChange('trial_price', parseFloat(e.target.value) || 0)}
                  className="neo-input"
                />
              </div>
              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                  Trial Duration (Days)
                </label>
                <input
                  type="number"
                  min="1"
                  max="30"
                  value={formData.trial_days ?? 2}
                  onChange={(e) => handleChange('trial_days', parseInt(e.target.value) || 0)}
                  className="neo-input"
                />
              </div>
            </div>
          </div>
        </div>

        {/* Feature Flags & App Controls Card */}
        <div className="neo-card" style={{ backgroundColor: '#FFFFFF' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '16px' }}>
            <span style={{ fontSize: '22px' }}>🎛️</span>
            <h3 style={{ fontSize: '18px' }}>Feature Flags & Release Version</h3>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                Active Production App Version
              </label>
              <input
                type="text"
                value={formData.latest_version || '1.0.0'}
                onChange={(e) => handleChange('latest_version', e.target.value)}
                className="neo-input"
              />
            </div>

            {/* Toggles */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginTop: '4px' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer', fontSize: '13px', fontWeight: 600 }}>
                <input
                  type="checkbox"
                  checked={formData.trial_enabled !== false}
                  onChange={() => handleToggle('trial_enabled')}
                  style={{ width: '18px', height: '18px', accentColor: 'var(--primary)' }}
                />
                <span>Enable ₹1 Trial Activation Flow</span>
              </label>

              <label style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer', fontSize: '13px', fontWeight: 600 }}>
                <input
                  type="checkbox"
                  checked={formData.garden_enabled !== false}
                  onChange={() => handleToggle('garden_enabled')}
                  style={{ width: '18px', height: '18px', accentColor: 'var(--primary)' }}
                />
                <span>Enable Multi-Plot Garden Tracker</span>
              </label>

              <label style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer', fontSize: '13px', fontWeight: 600 }}>
                <input
                  type="checkbox"
                  checked={formData.bulk_export_enabled !== false}
                  onChange={() => handleToggle('bulk_export_enabled')}
                  style={{ width: '18px', height: '18px', accentColor: 'var(--primary)' }}
                />
                <span>Enable Bulk Farm Diagnostic PDF Export</span>
              </label>

              <label style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer', fontSize: '13px', fontWeight: 600, color: 'var(--accent-red)' }}>
                <input
                  type="checkbox"
                  checked={!!formData.maintenance_mode}
                  onChange={() => handleToggle('maintenance_mode')}
                  style={{ width: '18px', height: '18px', accentColor: 'var(--accent-red)' }}
                />
                <span>Emergency Maintenance Mode (Lock app clients)</span>
              </label>
            </div>
          </div>
        </div>
      </div>

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
    </form>
  );
}
