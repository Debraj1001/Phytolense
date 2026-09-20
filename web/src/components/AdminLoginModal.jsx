// web/src/components/AdminLoginModal.jsx
import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { Shield, Lock, Mail, AlertTriangle, X, KeyRound } from 'lucide-react';

export default function AdminLoginModal() {
  const { loginModalOpen, setLoginModalOpen, handleAdminLogin } = useApp();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  if (!loginModalOpen) return null;

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const res = await handleAdminLogin(email, password);
      if (!res.success) {
        setError(res.error || 'Authentication rejected. Verify admin credentials.');
      }
    } catch (err) {
      setError(err.message || 'Authentication error occurred.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={() => setLoginModalOpen(false)}>
      <div 
        className="neo-card" 
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          maxWidth: '440px',
          backgroundColor: '#FFFFFF',
          padding: '28px'
        }}
      >
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: '20px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{
              width: '44px',
              height: '44px',
              backgroundColor: 'var(--primary)',
              borderRadius: 'var(--radius-md)',
              border: 'var(--border-width) solid var(--border-color)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <Shield size={22} color="#0F172A" />
            </div>
            <div>
              <h3 style={{ fontSize: '18px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                Admin Portal Login
              </h3>
              <p style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                Protected Administrative Gateway
              </p>
            </div>
          </div>
          <button 
            onClick={() => setLoginModalOpen(false)}
            style={{
              background: 'none',
              border: 'none',
              cursor: 'pointer',
              padding: '4px',
              borderRadius: '4px'
            }}
          >
            <X size={20} />
          </button>
        </div>

        {/* Security Shield Banner */}
        <div style={{
          backgroundColor: '#F8FAFC',
          border: 'var(--border-width-sm) solid var(--border-color)',
          borderRadius: 'var(--radius-md)',
          padding: '10px 14px',
          marginBottom: '20px',
          fontSize: '12px',
          display: 'flex',
          alignItems: 'center',
          gap: '10px'
        }}>
          <KeyRound size={16} color="var(--primary-dark)" />
          <span style={{ color: 'var(--text-secondary)', fontSize: '12px', fontWeight: 500 }}>
            Secure Portal. Authenticate using your registered administrative credentials.
          </span>
        </div>

        {error && (
          <div style={{
            backgroundColor: 'var(--accent-red-tint)',
            border: 'var(--border-width-sm) solid var(--accent-red)',
            borderRadius: 'var(--radius-md)',
            padding: '10px 14px',
            marginBottom: '16px',
            fontSize: '13px',
            color: 'var(--accent-red)',
            display: 'flex',
            alignItems: 'center',
            gap: '8px'
          }}>
            <AlertTriangle size={16} />
            <span>{error}</span>
          </div>
        )}

        {/* Form */}
        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px' }}>
              Administrator Email
            </label>
            <div style={{ position: 'relative' }}>
              <Mail size={16} style={{ position: 'absolute', left: '12px', top: '12px', color: 'var(--text-muted)' }} />
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="neo-input"
                style={{ paddingLeft: '38px' }}
                placeholder="admin@phytolens.com"
              />
            </div>
          </div>

          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px' }}>
              Admin Password
            </label>
            <div style={{ position: 'relative' }}>
              <Lock size={16} style={{ position: 'absolute', left: '12px', top: '12px', color: 'var(--text-muted)' }} />
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="neo-input"
                style={{ paddingLeft: '38px' }}
                placeholder="Enter password set up in Supabase"
              />
            </div>
          </div>

          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            fontSize: '11px',
            color: 'var(--text-secondary)',
            marginTop: '2px'
          }}>
            <KeyRound size={13} color="var(--primary-dark)" />
            <span>Authenticated directly via Supabase Auth & verified in admin table.</span>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="btn btn-primary"
            style={{ width: '100%', marginTop: '6px' }}
          >
            {loading ? 'Authenticating with Supabase...' : 'Authenticate & Enter Portal →'}
          </button>
        </form>
      </div>
    </div>
  );
}
