import React, { useState } from 'react';
import { useApp } from '../../context/AppContext';
import { 
  BarChart3, 
  Settings, 
  Cpu, 
  Users, 
  QrCode, 
  Radio, 
  LogOut, 
  ExternalLink, 
  RefreshCw, 
  ShieldCheck, 
  Sparkles,
  ChevronRight
} from 'lucide-react';
import ConfirmModal from '../Common/ConfirmModal';

export default function AdminLayout({ children }) {
  const { 
    adminSubPage, 
    setAdminSubPage, 
    adminUser, 
    handleAdminLogout, 
    setCurrentView,
    refreshData,
    loading
  } = useApp();

  const [logoutModalOpen, setLogoutModalOpen] = useState(false);

  const menuItems = [
    { id: 'dashboard', label: 'Dashboard & Usage', icon: BarChart3, badge: 'Live' },
    { id: 'config', label: 'App Configuration', icon: Settings, badge: 'Supabase' },
    { id: 'ai_usage', label: 'AI Usage & Tokens', icon: Cpu, badge: 'Per-User' },
    { id: 'users', label: 'User Management', icon: Users, badge: 'Full CRUD' },
    { id: 'qr_manager', label: 'QR & Download Setup', icon: QrCode, badge: 'Public Sync' },
    { id: 'field_telemetry', label: 'Outbreak & Retailers', icon: Radio, badge: 'Radar' }
  ];

  return (
    <div style={{
      display: 'flex',
      minHeight: '100vh',
      backgroundColor: 'var(--bg-canvas)'
    }}>
      {/* ─── Neobrutalist Admin Sidebar ───────────────────────────────────── */}
      <aside style={{
        width: '280px',
        backgroundColor: '#FFFFFF',
        borderRight: 'var(--border-width) solid var(--border-color)',
        display: 'flex',
        flexDirection: 'column',
        position: 'sticky',
        top: 0,
        height: '100vh',
        zIndex: 40,
        boxShadow: 'var(--shadow-sm)'
      }}>
        {/* Sidebar Header */}
        <div style={{
          padding: '20px',
          borderBottom: 'var(--border-width) solid var(--border-color)',
          backgroundColor: 'var(--primary-tint)'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px' }}>
            <div style={{
              width: '36px',
              height: '36px',
              backgroundColor: 'var(--primary)',
              border: 'var(--border-width-sm) solid var(--border-color)',
              borderRadius: 'var(--radius-md)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '18px',
              boxShadow: 'var(--shadow-sm)'
            }}>
              🌿
            </div>
            <div>
              <div style={{ fontWeight: 800, fontFamily: 'var(--font-display)', fontSize: '18px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                PhytoLens
                <span className="badge badge-dark" style={{ fontSize: '9px', padding: '2px 6px' }}>ADMIN</span>
              </div>
              <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                Command & Control Center
              </div>
            </div>
          </div>
        </div>

        {/* Admin Session Profile Card */}
        <div style={{
          padding: '12px 16px',
          borderBottom: 'var(--border-width) solid var(--border-color)',
          backgroundColor: 'var(--bg-subtle)'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px' }}>
            <ShieldCheck size={16} color="var(--primary-dark)" />
            <span style={{ fontSize: '11px', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
              Super Admin Session
            </span>
          </div>
          <div style={{
            fontSize: '12px',
            fontFamily: 'var(--font-mono)',
            fontWeight: 700,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap'
          }}>
            {adminUser?.email || 'noreplay.gkk26@gmail.com'}
          </div>
          <div style={{ fontSize: '10px', color: 'var(--text-muted)', marginTop: '2px' }}>
            Privilege Level: <span style={{ color: 'var(--primary-dark)', fontWeight: 700 }}>Root Authority (All Permissions)</span>
          </div>
        </div>

        {/* Navigation Section Links */}
        <div style={{
          flex: 1,
          padding: '16px 12px',
          overflowY: 'auto',
          display: 'flex',
          flexDirection: 'column',
          gap: '6px'
        }}>
          <div style={{ fontSize: '11px', fontWeight: 800, textTransform: 'uppercase', color: 'var(--text-muted)', padding: '0 8px 6px 8px' }}>
            Management Sections
          </div>

          {menuItems.map(item => {
            const Icon = item.icon;
            const isActive = adminSubPage === item.id;
            return (
              <button
                key={item.id}
                onClick={() => setAdminSubPage(item.id)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '10px 14px',
                  borderRadius: 'var(--radius-md)',
                  border: isActive ? 'var(--border-width) solid var(--border-color)' : '1.5px solid transparent',
                  backgroundColor: isActive ? 'var(--primary)' : 'transparent',
                  color: '#0F172A',
                  fontWeight: isActive ? 800 : 600,
                  fontSize: '13px',
                  fontFamily: 'var(--font-display)',
                  cursor: 'pointer',
                  boxShadow: isActive ? 'var(--shadow-sm)' : 'none',
                  transition: 'all 0.12s ease',
                  textAlign: 'left'
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <Icon size={18} />
                  <span>{item.label}</span>
                </div>
                <span className={`badge ${isActive ? 'badge-dark' : 'badge-emerald'}`} style={{ fontSize: '9px', padding: '2px 5px' }}>
                  {item.badge}
                </span>
              </button>
            );
          })}
        </div>

        {/* Bottom Actions Area */}
        <div style={{
          padding: '16px',
          borderTop: 'var(--border-width) solid var(--border-color)',
          display: 'flex',
          flexDirection: 'column',
          gap: '8px'
        }}>
          <button
            onClick={() => refreshData()}
            className="btn btn-white btn-sm"
            style={{ width: '100%', justifyContent: 'center' }}
            title="Reload live Supabase tables"
          >
            <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
            <span>{loading ? 'Refreshing...' : 'Sync Supabase Data'}</span>
          </button>

          <button
            onClick={() => setCurrentView('landing')}
            className="btn btn-outline btn-sm"
            style={{ width: '100%', justifyContent: 'center' }}
          >
            <ExternalLink size={14} />
            <span>View Public Landing Page</span>
          </button>

          <button
            onClick={() => setLogoutModalOpen(true)}
            className="btn btn-sm"
            style={{
              width: '100%',
              justifyContent: 'center',
              backgroundColor: 'var(--accent-red-tint)',
              color: 'var(--accent-red)',
              borderColor: 'var(--accent-red)'
            }}
          >
            <LogOut size={14} />
            <span>Sign Out Admin</span>
          </button>
        </div>
      </aside>

      {/* ─── Main Admin Workspace Content ─────────────────────────────────── */}
      <main style={{
        flex: 1,
        minWidth: 0,
        padding: '32px',
        overflowY: 'auto'
      }}>
        {children}
      </main>

      {/* ─── Neobrutalism Confirmation Modal ─────────────────────────────── */}
      <ConfirmModal
        isOpen={logoutModalOpen}
        title="Sign Out of Admin Portal?"
        message="Are you sure you want to end this root administrative session? You will return to the public landing page and need your admin credentials to access telemetry again."
        confirmText="Sign Out Safely"
        variant="danger"
        icon={<LogOut size={24} color="#EF4444" />}
        onConfirm={handleAdminLogout}
        onClose={() => setLogoutModalOpen(false)}
      />
    </div>
  );
}
