// web/src/components/LandingPage/Footer.jsx
import React from 'react';
import { useApp } from '../../context/AppContext';
import { Shield, Heart, ArrowUp } from 'lucide-react';

export default function Footer() {
  const { setLoginModalOpen } = useApp();

  const scrollToTop = () => {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  return (
    <footer style={{
      backgroundColor: '#0F172A',
      color: '#FFFFFF',
      borderTop: '3px solid #0F172A',
      padding: '48px 0 32px 0'
    }}>
      <div className="container">
        <div style={{
          display: 'flex',
          flexWrap: 'wrap',
          justifyContent: 'space-between',
          alignItems: 'center',
          gap: '24px',
          paddingBottom: '32px',
          borderBottom: '1px solid rgba(255, 255, 255, 0.15)'
        }}>
          {/* Logo & Tagline */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{
              width: '40px',
              height: '40px',
              backgroundColor: 'var(--primary)',
              borderRadius: 'var(--radius-md)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '20px'
            }}>
              🌿
            </div>
            <div>
              <div style={{ fontSize: '18px', fontWeight: 800, fontFamily: 'var(--font-display)' }}>
                PhytoLens
              </div>
              <div style={{ fontSize: '12px', color: '#94A3B8' }}>
                Hack2UK Plant Track · Precision Agronomy & Plant Health
              </div>
            </div>
          </div>

          {/* Quick Links */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '20px', fontSize: '13px', fontWeight: 600 }}>
            <a href="#problem" style={{ color: '#CBD5E1' }}>Crisis & Need</a>
            <a href="#showcase" style={{ color: '#CBD5E1' }}>App Showcase</a>
            <a href="#download-qr" style={{ color: '#CBD5E1' }}>Download QR</a>
            <button
              onClick={() => setLoginModalOpen(true)}
              style={{
                background: 'none',
                border: 'none',
                color: 'var(--primary)',
                fontWeight: 700,
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '4px'
              }}
            >
              <Shield size={14} />
              <span>Admin Portal ⚡</span>
            </button>
          </div>

          {/* Back to Top */}
          <button
            onClick={scrollToTop}
            className="btn btn-white btn-sm"
            style={{ display: 'flex', alignItems: 'center', gap: '6px' }}
          >
            <ArrowUp size={14} />
            <span>Top</span>
          </button>
        </div>

        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: '12px',
          paddingTop: '24px',
          fontSize: '12px',
          color: '#94A3B8'
        }}>
          <div>
            © {new Date().getFullYear()} PhytoLens. Built for Hack2UK Plant Track by <b>Debraj1001</b>. All rights reserved.
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <span>Powered by Gemini Vision · Groq LLaMA-3 · Supabase · Razorpay</span>
          </div>
        </div>
      </div>
    </footer>
  );
}
