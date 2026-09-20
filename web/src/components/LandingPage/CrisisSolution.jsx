// web/src/components/LandingPage/CrisisSolution.jsx
import React from 'react';
import { AlertCircle, CheckCircle2, XCircle, TrendingDown, Users, DollarSign, ShieldAlert, Sparkles } from 'lucide-react';

export default function CrisisSolution() {
  return (
    <section id="problem" className="section-py" style={{ backgroundColor: 'var(--bg-subtle)', borderTop: 'var(--border-width) solid var(--border-color)', borderBottom: 'var(--border-width) solid var(--border-color)' }}>
      <div className="container">
        {/* Section Header */}
        <div style={{ textAlign: 'center', maxWidth: '780px', margin: '0 auto 48px auto' }}>
          <span className="badge badge-amber" style={{ marginBottom: '12px' }}>
            The Agronomic Crisis
          </span>
          <h2 style={{ fontSize: 'clamp(28px, 4vw, 42px)', marginBottom: '16px' }}>
            Why Every Farmer Needs PhytoLens in Their Pocket
          </h2>
          <p style={{ fontSize: '16px' }}>
            According to the UN Food and Agriculture Organization (FAO), crop diseases wipe out 
            <b> 20% to 40% of global agricultural harvest</b> annually. Smallholder farmers—who produce 70% of 
            the world's food—are forced to rely on costly guesswork.
          </p>
        </div>

        {/* Problem Breakdown Cards */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
          gap: '20px',
          marginBottom: '48px'
        }}>
          <div className="neo-card" style={{ backgroundColor: '#FFFFFF' }}>
            <div style={{
              width: '40px',
              height: '40px',
              backgroundColor: 'var(--accent-red-tint)',
              borderRadius: 'var(--radius-md)',
              border: 'var(--border-width-sm) solid var(--border-color)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              marginBottom: '16px'
            }}>
              <TrendingDown size={22} color="var(--accent-red)" />
            </div>
            <h3 style={{ fontSize: '18px', marginBottom: '8px' }}>1. Catastrophic Late Detection</h3>
            <p style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>
              By the time fungal blight or viral leaf curl becomes obvious to the naked eye, the pathogen has already infiltrated vascular systems and spread to neighboring plots, destroying entire harvest cycles.
            </p>
          </div>

          <div className="neo-card" style={{ backgroundColor: '#FFFFFF' }}>
            <div style={{
              width: '40px',
              height: '40px',
              backgroundColor: 'var(--accent-amber-tint)',
              borderRadius: 'var(--radius-md)',
              border: 'var(--border-width-sm) solid var(--border-color)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              marginBottom: '16px'
            }}>
              <Users size={22} color="var(--accent-amber)" />
            </div>
            <h3 style={{ fontSize: '18px', marginBottom: '8px' }}>2. Absence of Rural Agronomists</h3>
            <p style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>
              In remote farming belts, the ratio of certified plant pathologists to growers is worse than 1:5,000. Physical soil & plant lab visits take weeks and cost hundreds of dollars that smallholders cannot afford.
            </p>
          </div>

          <div className="neo-card" style={{ backgroundColor: '#FFFFFF' }}>
            <div style={{
              width: '40px',
              height: '40px',
              backgroundColor: 'var(--secondary-tint)',
              borderRadius: 'var(--radius-md)',
              border: 'var(--border-width-sm) solid var(--border-color)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              marginBottom: '16px'
            }}>
              <ShieldAlert size={22} color="var(--secondary)" />
            </div>
            <h3 style={{ fontSize: '18px', marginBottom: '8px' }}>3. Guesswork & Counterfeit Inputs</h3>
            <p style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>
              Desperate growers often purchase incorrect broad-spectrum fungicides from unregulated shops. This leads to pesticide resistance, toxic chemical runoff, and zero curative effect on the affected plants.
            </p>
          </div>
        </div>

        {/* Side-by-Side Comparison Box */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
          gap: '24px'
        }}>
          {/* Old Traditional Way */}
          <div className="neo-card" style={{ backgroundColor: '#FFF5F5', borderColor: '#DC2626' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '16px' }}>
              <XCircle size={24} color="#DC2626" />
              <h3 style={{ fontSize: '20px', color: '#991B1B' }}>Traditional Guesswork</h3>
            </div>
            <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '12px', fontSize: '14px' }}>
              <li style={{ display: 'flex', gap: '8px' }}>
                <span style={{ color: '#DC2626', fontWeight: 800 }}>✕</span>
                <span>Wait 5–10 days for an agricultural extension officer to visit.</span>
              </li>
              <li style={{ display: 'flex', gap: '8px' }}>
                <span style={{ color: '#DC2626', fontWeight: 800 }}>✕</span>
                <span>Unverified hearsay from neighbors leading to spraying wrong chemical cocktails.</span>
              </li>
              <li style={{ display: 'flex', gap: '8px' }}>
                <span style={{ color: '#DC2626', fontWeight: 800 }}>✕</span>
                <span>Spraying right before sudden rain, washing expensive chemicals into water tables.</span>
              </li>
              <li style={{ display: 'flex', gap: '8px' }}>
                <span style={{ color: '#DC2626', fontWeight: 800 }}>✕</span>
                <span>High cost barrier: expensive diagnostics or total crop write-off.</span>
              </li>
            </ul>
          </div>

          {/* PhytoLens Way */}
          <div className="neo-card" style={{ backgroundColor: '#F0FDF4', borderColor: 'var(--primary-dark)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '16px' }}>
              <CheckCircle2 size={24} color="var(--primary-dark)" />
              <h3 style={{ fontSize: '20px', color: 'var(--primary-dark)' }}>The PhytoLens Standard</h3>
            </div>
            <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '12px', fontSize: '14px' }}>
              <li style={{ display: 'flex', gap: '8px' }}>
                <span style={{ color: 'var(--primary-dark)', fontWeight: 800 }}>✓</span>
                <span><b>Instant 1.2s Diagnosis</b> via smartphone camera, with 100% offline edge TFLite backup.</span>
              </li>
              <li style={{ display: 'flex', gap: '8px' }}>
                <span style={{ color: 'var(--primary-dark)', fontWeight: 800 }}>✓</span>
                <span><b>Exact chemical active ingredients</b> (e.g. Mancozeb 75% WP @ 2.5g/L) plus organic bio-sprays.</span>
              </li>
              <li style={{ display: 'flex', gap: '8px' }}>
                <span style={{ color: 'var(--primary-dark)', fontWeight: 800 }}>✓</span>
                <span><b>Atmospheric Spray Advisory</b>: Evaluates humidity, wind, and precipitation probability.</span>
              </li>
              <li style={{ display: 'flex', gap: '8px' }}>
                <span style={{ color: 'var(--primary-dark)', fontWeight: 800 }}>✓</span>
                <span><b>₹10 Emergency Doctor Pass</b>: Immediate 24h prioritized botanist consultation via Razorpay.</span>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </section>
  );
}
