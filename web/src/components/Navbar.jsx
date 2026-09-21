// web/src/components/Navbar.jsx
import React from 'react';
import { useApp } from '../context/AppContext';
import { Shield, Sparkles, QrCode, Smartphone, Layers, Leaf, ExternalLink } from 'lucide-react';

export default function Navbar() {
  const { currentView, setCurrentView, adminUser, setLoginModalOpen, setAdminSubPage, appConfig } = useApp();
  const version = appConfig?.latest_version || '1.0.2';
  const displayVersion = version.startsWith('v') ? version : `v${version}`;

  const handleAdminClick = () => {
    if (adminUser) {
      setCurrentView('admin');
      setAdminSubPage('dashboard');
    } else {
      setLoginModalOpen(true);
    }
  };

  return (
    <header style={{
      position: 'sticky',
      top: 0,
      zIndex: 50,
      backgroundColor: 'rgba(255, 255, 255, 0.95)',
      backdropFilter: 'blur(8px)',
      borderBottom: 'var(--border-width) solid var(--border-color)',
      boxShadow: 'var(--shadow-sm)'
    }}>
      <div className="container" style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        height: '72px'
      }}>
        {/* Brand Logo */}
        <div 
          onClick={() => setCurrentView('landing')}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            cursor: 'pointer',
            userSelect: 'none'
          }}
        >
          <div style={{
            width: '42px',
            height: '42px',
            borderRadius: 'var(--radius-md)',
            backgroundColor: 'var(--primary)',
            border: 'var(--border-width) solid var(--border-color)',
            boxShadow: 'var(--shadow-sm)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '22px'
          }}>
            🌿
          </div>
          <div>
            <div style={{
              fontFamily: 'var(--font-display)',
              fontWeight: 800,
              fontSize: '20px',
              letterSpacing: '-0.02em',
              display: 'flex',
              alignItems: 'center',
              gap: '6px'
            }}>
              PhytoLens
              <span className="badge badge-emerald" style={{ fontSize: '10px', padding: '2px 6px' }}>{displayVersion}</span>
            </div>
            <div style={{ fontSize: '11px', color: 'var(--text-secondary)', fontWeight: 500 }}>
              AI Plant Pathology & Agronomy Engine
            </div>
          </div>
        </div>

        {/* Navigation Anchors (Landing Page Mode) */}
        {currentView === 'landing' && (
          <nav style={{
            display: 'flex',
            alignItems: 'center',
            gap: '24px'
          }} className="nav-links">
            <a href="#problem" style={{ fontWeight: 600, fontSize: '14px', color: 'var(--text-secondary)' }}>
              Crisis & Need
            </a>
            <a href="#showcase" style={{ fontWeight: 600, fontSize: '14px', color: 'var(--text-secondary)' }}>
              Interactive App
            </a>
            <a href="#download-qr" style={{ fontWeight: 600, fontSize: '14px', color: 'var(--text-secondary)' }}>
              Get App (QR)
            </a>
            <a href="#technology" style={{ fontWeight: 600, fontSize: '14px', color: 'var(--text-secondary)' }}>
              AI Architecture
            </a>
          </nav>
        )}

        {/* Right CTA Area */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          {currentView === 'admin' ? (
            <button
              onClick={() => setCurrentView('landing')}
              className="btn btn-outline btn-sm"
            >
              ← Back to Public Website
            </button>
          ) : (
            <a
              href="#download-qr"
              className="btn btn-white btn-sm"
              style={{ display: 'flex', alignItems: 'center', gap: '6px' }}
            >
              <QrCode size={15} />
              <span>Download App</span>
            </a>
          )}

          {/* Admin Portal Button */}
          <button
            onClick={handleAdminClick}
            className="btn btn-primary btn-sm"
            style={{
              fontWeight: 700,
              display: 'flex',
              alignItems: 'center',
              gap: '6px'
            }}
          >
            <Shield size={15} />
            <span>{adminUser ? 'Admin Dashboard ⚡' : 'Admin Portal ⚡'}</span>
          </button>
        </div>
      </div>
    </header>
  );
}
