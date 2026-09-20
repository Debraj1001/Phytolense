// web/src/components/LandingPage/TechSpecs.jsx
import React from 'react';
import { Cpu, ShieldCheck, Database, Zap, RefreshCw, Smartphone, Layers } from 'lucide-react';

export default function TechSpecs() {
  const specs = [
    {
      icon: RefreshCw,
      title: 'Multi-Key Gemini Vision Pool',
      desc: 'Automatic failover pool across 5 rotated API keys. When one key hits rate limits, the next backup key instantly absorbs the load with 0ms downtime.'
    },
    {
      icon: Cpu,
      title: 'On-Device TFLite Edge Inference',
      desc: '38+ disease models packaged into lightweight TensorFlow Lite & ONNX weights for low-latency pathology detection without requiring internet access.'
    },
    {
      icon: Zap,
      title: 'Groq LLaMA-3 Agronomy Engine',
      desc: 'Sub-second prescription generation providing exact chemical active ingredients, mixing dilution tables, safety intervals, and homemade organic cures.'
    },
    {
      icon: Layers,
      title: '82,000+ Species Identification',
      desc: 'Direct integration with PlantNet botanical taxonomy API to identify species across European, Asian, and American agricultural crops.'
    },
    {
      icon: Database,
      title: 'Offline-First SQLite + Supabase Sync',
      desc: 'Local SQLite database records all garden plots, health logs, and diagnostic scans, synchronizing with Supabase PostgreSQL as soon as connectivity resumes.'
    },
    {
      icon: ShieldCheck,
      title: 'Razorpay Micro-Checkout Architecture',
      desc: 'Secure payment verification through Supabase Edge Functions with instant activation of the ₹10 Emergency Doctor Pass.'
    }
  ];

  return (
    <section id="technology" className="section-py" style={{ position: 'relative' }}>
      <div className="container">
        <div style={{ textAlign: 'center', maxWidth: '780px', margin: '0 auto 48px auto' }}>
          <span className="badge badge-sky" style={{ marginBottom: '12px' }}>
            System Architecture
          </span>
          <h2 style={{ fontSize: 'clamp(28px, 4vw, 42px)', marginBottom: '16px' }}>
            Resilient Multimodal AI Pipeline
          </h2>
          <p style={{ fontSize: '16px' }}>
            Engineered to thrive in remote, bandwidth-constrained agricultural fields through dual-engine inference and multi-cloud resilience.
          </p>
        </div>

        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
          gap: '20px'
        }}>
          {specs.map((s, idx) => {
            const Icon = s.icon;
            return (
              <div key={idx} className="neo-card hoverable" style={{ backgroundColor: '#FFFFFF' }}>
                <div style={{
                  width: '42px',
                  height: '42px',
                  backgroundColor: 'var(--primary-tint)',
                  borderRadius: 'var(--radius-md)',
                  border: 'var(--border-width-sm) solid var(--border-color)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  marginBottom: '14px'
                }}>
                  <Icon size={22} color="var(--primary-dark)" />
                </div>
                <h3 style={{ fontSize: '18px', marginBottom: '8px' }}>{s.title}</h3>
                <p style={{ fontSize: '14px', color: 'var(--text-secondary)', lineHeight: 1.5 }}>
                  {s.desc}
                </p>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
