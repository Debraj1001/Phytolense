// web/src/components/LandingPage/Hero.jsx
import React from 'react';
import { useApp } from '../../context/AppContext';
import { QrCode, Shield, ArrowRight, Zap, CheckCircle2, Award, Cpu, WifiOff } from 'lucide-react';

export default function Hero() {
  const { setLoginModalOpen, setQrZoomModalOpen } = useApp();

  return (
    <section className="section-py" style={{ paddingTop: '56px', position: 'relative' }}>
      <div className="container">
        {/* Top Badges */}
        <div style={{
          display: 'flex',
          flexWrap: 'wrap',
          alignItems: 'center',
          gap: '10px',
          marginBottom: '20px'
        }}>
          <span className="badge badge-emerald">
            <span className="pulse-dot" />
            <span>Hack2UK Plant Track Finalist</span>
          </span>
          <span className="badge badge-mint">
            <Cpu size={12} />
            <span>Dual-Engine: Cloud Multimodal + Edge TFLite</span>
          </span>
          <span className="badge badge-amber">
            <WifiOff size={12} />
            <span>100% Offline Diagnostic Ready</span>
          </span>
        </div>

        {/* Main Hero Header */}
        <div style={{ maxWidth: '920px' }}>
          <h1 style={{
            fontSize: 'clamp(36px, 5.5vw, 62px)',
            lineHeight: 1.08,
            marginBottom: '20px'
          }}>
            AI-Powered Plant Health & Agronomic Intelligence for <span style={{
              backgroundColor: 'var(--primary)',
              padding: '2px 10px',
              border: 'var(--border-width) solid var(--border-color)',
              borderRadius: 'var(--radius-md)',
              boxShadow: 'var(--shadow-sm)',
              display: 'inline-block'
            }}>Every Grower</span>
          </h1>

          <p style={{
            fontSize: 'clamp(16px, 2vw, 20px)',
            color: 'var(--text-secondary)',
            marginBottom: '32px',
            lineHeight: 1.5,
            maxWidth: '780px'
          }}>
            Bridge the gap between crop pathology identification and actionable physical cures. 
            PhytoLens delivers <b>sub-second leaf disease diagnosis</b>, instant chemical & organic 
            prescriptions via Groq AI, 10km community outbreak warnings, and direct connections to verified agro-retailers.
          </p>

          {/* Action CTAs */}
          <div style={{
            display: 'flex',
            flexWrap: 'wrap',
            alignItems: 'center',
            gap: '14px',
            marginBottom: '48px'
          }}>
            <a
              href="#download-qr"
              className="btn btn-primary btn-lg"
              style={{ display: 'flex', alignItems: 'center', gap: '8px' }}
            >
              <QrCode size={20} />
              <span>Scan QR to Get App</span>
              <ArrowRight size={18} />
            </a>

            <a
              href="#showcase"
              className="btn btn-white btn-lg"
            >
              <span>Explore Interactive App Demo 📱</span>
            </a>

            <button
              onClick={() => setLoginModalOpen(true)}
              className="btn btn-dark btn-lg"
              style={{ display: 'flex', alignItems: 'center', gap: '8px' }}
            >
              <Shield size={18} />
              <span>Admin Portal ⚡</span>
            </button>
          </div>
        </div>

        {/* Neobrutalist Live Metrics Strip */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(190px, 1fr))',
          gap: '16px'
        }}>
          <div className="neo-card" style={{ padding: '18px', backgroundColor: '#FFFFFF' }}>
            <div style={{ fontSize: '12px', fontWeight: 700, color: 'var(--text-secondary)', textTransform: 'uppercase', marginBottom: '6px' }}>
              🔬 Pathology Coverage
            </div>
            <div style={{ fontSize: '32px', fontWeight: 800, fontFamily: 'var(--font-display)', color: 'var(--primary-dark)' }}>
              38+ Diseases
            </div>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>
              Blite, mildew, rust, viral rots & molds
            </div>
          </div>

          <div className="neo-card" style={{ padding: '18px', backgroundColor: '#FFFFFF' }}>
            <div style={{ fontSize: '12px', fontWeight: 700, color: 'var(--text-secondary)', textTransform: 'uppercase', marginBottom: '6px' }}>
              🌿 Botanical Species
            </div>
            <div style={{ fontSize: '32px', fontWeight: 800, fontFamily: 'var(--font-display)', color: '#0F172A' }}>
              82,000+
            </div>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>
              Global flora catalog via PlantNet API
            </div>
          </div>

          <div className="neo-card" style={{ padding: '18px', backgroundColor: '#FFFFFF' }}>
            <div style={{ fontSize: '12px', fontWeight: 700, color: 'var(--text-secondary)', textTransform: 'uppercase', marginBottom: '6px' }}>
              ⚡ Detection Latency
            </div>
            <div style={{ fontSize: '32px', fontWeight: 800, fontFamily: 'var(--font-display)', color: 'var(--secondary)' }}>
              &lt; 1.2s
            </div>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>
              Multi-key Gemini Vision + TFLite offline
            </div>
          </div>

          <div className="neo-card" style={{ padding: '18px', backgroundColor: '#FFFFFF' }}>
            <div style={{ fontSize: '12px', fontWeight: 700, color: 'var(--text-secondary)', textTransform: 'uppercase', marginBottom: '6px' }}>
              🩺 Emergency Pass
            </div>
            <div style={{ fontSize: '32px', fontWeight: 800, fontFamily: 'var(--font-display)', color: 'var(--accent-amber)' }}>
              ₹10 / 24h
            </div>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>
              Razorpay micro-checkout for crisis relief
            </div>
          </div>

          <div className="neo-card" style={{ padding: '18px', backgroundColor: '#FFFFFF' }}>
            <div style={{ fontSize: '12px', fontWeight: 700, color: 'var(--text-secondary)', textTransform: 'uppercase', marginBottom: '6px' }}>
              📡 Community Radar
            </div>
            <div style={{ fontSize: '32px', fontWeight: 800, fontFamily: 'var(--font-display)', color: 'var(--primary)' }}>
              10 km
            </div>
            <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>
              Geo-radius epidemic alert telemetry
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
