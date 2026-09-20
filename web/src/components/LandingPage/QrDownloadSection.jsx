// web/src/components/LandingPage/QrDownloadSection.jsx
import React, { useState, useEffect } from 'react';
import { useApp } from '../../context/AppContext';
import QRCode from 'qrcode';
import { 
  QrCode, 
  ZoomIn, 
  Download, 
  Copy, 
  Check, 
  Smartphone, 
  ExternalLink, 
  ShieldCheck, 
  Apple, 
  Clock, 
  Sparkles,
  Info
} from 'lucide-react';

const OFFICIAL_APK_DOWNLOAD_URL = 'https://github.com/Debraj1001/Phytolense/releases/download/v1.0.0/phytolens-v1.0.0.apk';
const OFFICIAL_GITHUB_RELEASE_URL = 'https://github.com/Debraj1001/Phytolense/releases/tag/v1.0.0';

export default function QrDownloadSection() {
  const { appConfig, setQrZoomModalOpen, showToast } = useApp();
  const [svgMarkup, setSvgMarkup] = useState('');
  const [copied, setCopied] = useState(false);

  // Active verified download link
  const androidUrl = appConfig?.download_url_android || OFFICIAL_APK_DOWNLOAD_URL;
  const githubReleaseUrl = appConfig?.download_url_github_release || OFFICIAL_GITHUB_RELEASE_URL;

  // Primary target for QR code: always the direct APK download so scanning immediately triggers installation
  const qrTarget = androidUrl;

  useEffect(() => {
    if (!qrTarget) return;

    // Render clean, high-contrast, camera-readable QR code
    QRCode.toString(qrTarget, {
      type: 'svg',
      errorCorrectionLevel: 'M',
      margin: 2,
      color: {
        dark: '#0F172A',
        light: '#FFFFFF'
      }
    }, (err, svgString) => {
      if (!err && svgString) {
        setSvgMarkup(svgString);
      }
    });
  }, [qrTarget]);

  const handleCopy = () => {
    navigator.clipboard.writeText(qrTarget);
    setCopied(true);
    showToast('Direct APK link copied to clipboard! 📋');
    setTimeout(() => setCopied(false), 2000);
  };

  const handlePlayStoreNotice = (e) => {
    e.preventDefault();
    showToast('⏳ Google Play Store review is in progress! You can download and install the official APK directly right now.', 'info');
  };

  const handleIosNotice = (e) => {
    e.preventDefault();
    showToast('⏳ iOS build is in closed preview. Android APK direct download is available immediately.', 'info');
  };

  return (
    <section id="download-qr" className="section-py" style={{
      backgroundColor: 'var(--primary-tint)',
      borderTop: 'var(--border-width) solid var(--border-color)',
      borderBottom: 'var(--border-width) solid var(--border-color)'
    }}>
      <div className="container">
        {/* Header */}
        <div style={{ textAlign: 'center', maxWidth: '800px', margin: '0 auto 40px auto' }}>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', marginBottom: '12px' }}>
            <span className="badge badge-emerald" style={{ display: 'inline-flex', alignItems: 'center', gap: '6px' }}>
              <Sparkles size={12} />
              Official v1.0.0 Production Release
            </span>
            <span className="badge badge-mint">
              100% Offline Edge AI Ready
            </span>
          </div>
          <h2 style={{ fontSize: 'clamp(28px, 4vw, 42px)', marginBottom: '16px', fontWeight: 900 }}>
            Scan to Download PhytoLens
          </h2>
          <p style={{ fontSize: '16px', color: 'var(--text-secondary)', lineHeight: 1.6 }}>
            Point any standard smartphone camera or Google Lens directly at the high-contrast QR code below. 
            Enjoy immediate installation with 100% offline edge agronomic inference and zero cloud latency.
          </p>
        </div>

        {/* Central Neobrutalist QR Card */}
        <div style={{
          maxWidth: '860px',
          margin: '0 auto',
          backgroundColor: '#FFFFFF',
          borderRadius: 'var(--radius-lg)',
          border: 'var(--border-width) solid var(--border-color)',
          boxShadow: 'var(--shadow-xl)',
          padding: 'clamp(20px, 4vw, 36px)'
        }}>
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
            gap: '36px',
            alignItems: 'center'
          }}>
            {/* Left: 100% Camera-Scannable QR Code */}
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
              <div 
                style={{
                  padding: '16px',
                  backgroundColor: '#FFFFFF',
                  borderRadius: 'var(--radius-lg)',
                  border: '3px solid #0F172A',
                  boxShadow: 'var(--shadow-lg)',
                  position: 'relative',
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                  transition: 'transform 0.15s ease, box-shadow 0.15s ease'
                }}
                onClick={() => setQrZoomModalOpen(true)}
                title="Click to open Lossless Zoom & High-Res Export"
              >
                {/* Crisp Vector SVG QR Code with no central obstruction */}
                <div 
                  style={{ width: '220px', height: '220px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                  dangerouslySetInnerHTML={{ __html: svgMarkup }}
                />

                {/* Top Floating Badge */}
                <div style={{
                  position: 'absolute',
                  top: '-12px',
                  backgroundColor: '#0F172A',
                  color: '#FFFFFF',
                  fontSize: '10px',
                  fontWeight: 800,
                  letterSpacing: '0.05em',
                  textTransform: 'uppercase',
                  padding: '3px 10px',
                  borderRadius: '12px',
                  boxShadow: '0 2px 6px rgba(0,0,0,0.15)'
                }}>
                  Direct APK Target
                </div>
              </div>

              {/* Lossless Zooming CTA Button */}
              <div style={{ display: 'flex', gap: '8px', marginTop: '16px' }}>
                <button
                  onClick={() => setQrZoomModalOpen(true)}
                  className="btn btn-dark btn-sm"
                  style={{ display: 'flex', alignItems: 'center', gap: '8px' }}
                >
                  <ZoomIn size={15} />
                  <span>Lossless Zoom / High-Res</span>
                </button>
              </div>

              <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '10px', maxWidth: '240px', lineHeight: 1.4 }}>
                📷 Guaranteed scannable by all Android & iOS camera lenses without app store accounts.
              </div>
            </div>

            {/* Right: Download Channels & Quick Actions */}
            <div>
              <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: '8px', marginBottom: '10px' }}>
                <span className="badge badge-mint" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                  <ShieldCheck size={12} />
                  Official Release v1.0.0
                </span>
                <span className="badge badge-emerald">136.6 MB APK</span>
                <span className="badge badge-amber">Production Build</span>
              </div>

              <h3 style={{ fontSize: '22px', marginBottom: '8px', fontWeight: 800 }}>
                Install PhytoLens on Android
              </h3>

              <p style={{ fontSize: '13.5px', color: 'var(--text-secondary)', marginBottom: '18px', lineHeight: 1.5 }}>
                Direct APK download delivers immediate access to our on-device edge AI disease scanner, field agronomy assistant, and farm telemetry.
              </p>

              {/* Platform Download Channels */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginBottom: '18px' }}>
                
                {/* 1. Primary Live Download Button */}
                <a
                  href={androidUrl}
                  download="phytolens-v1.0.0.apk"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="btn btn-primary"
                  style={{ 
                    justifyContent: 'space-between', 
                    padding: '12px 18px',
                    boxShadow: 'var(--shadow-md)',
                    border: '2px solid #0F172A'
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <div style={{
                      backgroundColor: 'rgba(255,255,255,0.2)',
                      borderRadius: '8px',
                      padding: '6px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center'
                    }}>
                      <Smartphone size={20} />
                    </div>
                    <div style={{ textAlign: 'left' }}>
                      <div style={{ fontSize: '14px', fontWeight: 800 }}>Download Android APK</div>
                      <div style={{ fontSize: '11px', opacity: 0.9 }}>Direct Release (.apk) · v1.0.0 · Ready Now</div>
                    </div>
                  </div>
                  <Download size={20} />
                </a>

                {/* 2. Google Play Store - Coming Soon */}
                <div
                  onClick={handlePlayStoreNotice}
                  className="neo-card"
                  style={{ 
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '10px 16px',
                    cursor: 'pointer',
                    backgroundColor: '#F8FAFC',
                    border: '1.5px dashed #CBD5E1',
                    borderRadius: 'var(--radius-md)',
                    opacity: 0.92
                  }}
                  title="Under Google Play Review - Click for details"
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <span style={{ fontSize: '18px' }}>▶️</span>
                    <div style={{ textAlign: 'left' }}>
                      <div style={{ fontSize: '13px', fontWeight: 700, color: 'var(--text-primary)' }}>
                        Google Play Store
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                        Store listing in submission review
                      </div>
                    </div>
                  </div>
                  <span className="badge badge-amber" style={{ fontSize: '11px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <Clock size={11} />
                    Coming Soon
                  </span>
                </div>

                {/* 3. Apple App Store & iOS TestFlight - Coming Soon */}
                <div
                  onClick={handleIosNotice}
                  className="neo-card"
                  style={{ 
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '10px 16px',
                    cursor: 'pointer',
                    backgroundColor: '#F8FAFC',
                    border: '1.5px dashed #CBD5E1',
                    borderRadius: 'var(--radius-md)',
                    opacity: 0.92
                  }}
                  title="iOS Beta Preview - Click for details"
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <Apple size={18} color="var(--text-primary)" />
                    <div style={{ textAlign: 'left' }}>
                      <div style={{ fontSize: '13px', fontWeight: 700, color: 'var(--text-primary)' }}>
                        Apple App Store & TestFlight
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                        iOS closed beta in preparation
                      </div>
                    </div>
                  </div>
                  <span className="badge badge-amber" style={{ fontSize: '11px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <Clock size={11} />
                    Coming Soon
                  </span>
                </div>

                {/* 4. GitHub Release Page Link */}
                <a
                  href={githubReleaseUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="btn btn-white btn-sm"
                  style={{ 
                    justifyContent: 'space-between', 
                    padding: '8px 14px',
                    border: '1px solid #CBD5E1',
                    fontSize: '12px'
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                      <path fillRule="evenodd" clipRule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"/>
                    </svg>
                    <span>View GitHub Release Notes & Source (Debraj1001/Phytolense)</span>
                  </div>
                  <ExternalLink size={13} />
                </a>
              </div>

              {/* Copy URL Bar */}
              <div style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                padding: '8px 12px',
                backgroundColor: 'var(--bg-subtle)',
                borderRadius: 'var(--radius-md)',
                border: 'var(--border-width-sm) solid var(--border-color)',
                fontSize: '11.5px'
              }}>
                <span style={{
                  fontFamily: 'var(--font-mono)',
                  color: 'var(--text-secondary)',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: 'nowrap',
                  flex: 1
                }}>
                  {qrTarget}
                </span>

                <button
                  onClick={handleCopy}
                  className="btn btn-white btn-sm"
                  style={{ padding: '4px 10px', fontSize: '11px', flexShrink: 0 }}
                  title="Copy direct APK download URL"
                >
                  {copied ? <Check size={13} color="var(--primary-dark)" /> : <Copy size={13} />}
                  <span>{copied ? 'Copied' : 'Copy'}</span>
                </button>
              </div>

              {/* Other stores subtle note */}
              <div style={{ 
                marginTop: '12px', 
                display: 'flex', 
                alignItems: 'center', 
                gap: '6px', 
                fontSize: '11px', 
                color: 'var(--text-muted)' 
              }}>
                <Info size={13} />
                <span>Submissions in progress for Amazon Appstore and F-Droid.</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
