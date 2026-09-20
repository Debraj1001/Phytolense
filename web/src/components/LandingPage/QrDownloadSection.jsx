// web/src/components/LandingPage/QrDownloadSection.jsx
import React, { useState, useEffect } from 'react';
import { useApp } from '../../context/AppContext';
import QRCode from 'qrcode';
import { QrCode, ZoomIn, Download, Copy, Check, Smartphone, ExternalLink, ShieldCheck, Apple, Play } from 'lucide-react';

export default function QrDownloadSection() {
  const { appConfig, setQrZoomModalOpen, showToast } = useApp();
  const [svgMarkup, setSvgMarkup] = useState('');
  const [copied, setCopied] = useState(false);

  // Active download links from Admin App Config
  const androidUrl = appConfig?.download_url_android || 'https://github.com/Debraj1001/Phytolense/releases/latest/download/phytolens-release.apk';
  const playStoreUrl = appConfig?.download_url_playstore || 'https://play.google.com/store/apps/details?id=com.phytolens.app';
  const iosUrl = appConfig?.download_url_ios || 'https://testflight.apple.com/join/phytolens';
  const webUrl = appConfig?.download_url_web || 'https://phytolens.agritech.org';

  // Primary target for QR code
  const qrTarget = appConfig?.qr_primary_target === 'playstore' ? playStoreUrl : androidUrl;

  useEffect(() => {
    if (!qrTarget) return;

    QRCode.toString(qrTarget, {
      type: 'svg',
      errorCorrectionLevel: appConfig?.qr_error_correction || 'H',
      margin: 1,
      color: {
        dark: appConfig?.qr_foreground_color || '#0F172A',
        light: '#FFFFFF'
      }
    }, (err, svgString) => {
      if (!err && svgString) {
        setSvgMarkup(svgString);
      }
    });
  }, [qrTarget, appConfig]);

  const handleCopy = () => {
    navigator.clipboard.writeText(qrTarget);
    setCopied(true);
    showToast('Download link copied to clipboard! 📋');
    setTimeout(() => setCopied(false), 2000);
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
          <span className="badge badge-emerald" style={{ marginBottom: '12px' }}>
            Instant Mobile Installation
          </span>
          <h2 style={{ fontSize: 'clamp(28px, 4vw, 42px)', marginBottom: '16px' }}>
            Scan to Download PhytoLens
          </h2>
          <p style={{ fontSize: '16px', color: 'var(--text-secondary)' }}>
            Point any standard smartphone camera or Google Lens directly at the high-contrast QR code below. 
            Enjoy immediate installation with 100% offline edge inference support.
          </p>
        </div>

        {/* Central Neobrutalist QR Card */}
        <div style={{
          maxWidth: '820px',
          margin: '0 auto',
          backgroundColor: '#FFFFFF',
          borderRadius: 'var(--radius-lg)',
          border: 'var(--border-width) solid var(--border-color)',
          boxShadow: 'var(--shadow-xl)',
          padding: 'clamp(20px, 4vw, 36px)'
        }}>
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
            gap: '32px',
            alignItems: 'center'
          }}>
            {/* Left: Big Camera-Ready QR Code */}
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
              <div style={{
                padding: '16px',
                backgroundColor: '#FFFFFF',
                borderRadius: 'var(--radius-lg)',
                border: '3px solid #0F172A',
                boxShadow: 'var(--shadow-lg)',
                position: 'relative',
                display: 'inline-flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer'
              }}
              onClick={() => setQrZoomModalOpen(true)}
              title="Click to open Lossless Zoom Viewer"
              >
                {/* Crisp Vector SVG QR Code */}
                <div 
                  style={{ width: '220px', height: '220px' }}
                  dangerouslySetInnerHTML={{ __html: svgMarkup }}
                />

                {/* Central Leaf Badge */}
                {appConfig?.qr_logo_enabled !== false && (
                  <div style={{
                    position: 'absolute',
                    width: '38px',
                    height: '38px',
                    backgroundColor: 'var(--primary)',
                    borderRadius: '50%',
                    border: '2px solid #0F172A',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: '18px',
                    boxShadow: '0 2px 5px rgba(0,0,0,0.2)'
                  }}>
                    🌿
                  </div>
                )}
              </div>

              {/* Lossless Zooming CTA Button */}
              <button
                onClick={() => setQrZoomModalOpen(true)}
                className="btn btn-dark btn-sm"
                style={{ marginTop: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}
              >
                <ZoomIn size={16} />
                <span>Lossless Zoom to Fullscreen 🔍</span>
              </button>

              <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '8px' }}>
                Vector SVG rendered · Zero pixel loss · Camera scan guaranteed
              </div>
            </div>

            {/* Right: Download Channels & Quick Actions */}
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px' }}>
                <span className="badge badge-mint">Official Release</span>
                <span className="badge badge-emerald">SHA-256 Verified</span>
              </div>

              <h3 style={{ fontSize: '22px', marginBottom: '12px' }}>
                Available for Android & iOS
              </h3>

              <p style={{ fontSize: '14px', color: 'var(--text-secondary)', marginBottom: '20px', lineHeight: 1.5 }}>
                Direct APK download ensures farmers with low bandwidth or restricted app store accounts can install PhytoLens instantly.
              </p>

              {/* Platform Download Buttons */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginBottom: '20px' }}>
                <a
                  href={androidUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="btn btn-primary"
                  style={{ justifyContent: 'space-between', padding: '12px 18px' }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <Smartphone size={18} />
                    <div style={{ textAlign: 'left' }}>
                      <div style={{ fontSize: '14px', fontWeight: 800 }}>Download Android APK</div>
                      <div style={{ fontSize: '11px', opacity: 0.85 }}>Direct Release (.apk) · v1.0.0</div>
                    </div>
                  </div>
                  <Download size={18} />
                </a>

                <a
                  href={playStoreUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="btn btn-white"
                  style={{ justifyContent: 'space-between', padding: '10px 16px' }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <span style={{ fontSize: '18px' }}>▶️</span>
                    <div style={{ textAlign: 'left' }}>
                      <div style={{ fontSize: '13px', fontWeight: 700 }}>Google Play Store</div>
                      <div style={{ fontSize: '10px', color: 'var(--text-muted)' }}>Verified distribution</div>
                    </div>
                  </div>
                  <ExternalLink size={15} />
                </a>

                <a
                  href={iosUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="btn btn-white"
                  style={{ justifyContent: 'space-between', padding: '10px 16px' }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <Apple size={18} />
                    <div style={{ textAlign: 'left' }}>
                      <div style={{ fontSize: '13px', fontWeight: 700 }}>iOS TestFlight Preview</div>
                      <div style={{ fontSize: '10px', color: 'var(--text-muted)' }}>Public beta build</div>
                    </div>
                  </div>
                  <ExternalLink size={15} />
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
                fontSize: '12px'
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
                  style={{ padding: '4px 10px', fontSize: '11px' }}
                >
                  {copied ? <Check size={13} color="var(--primary-dark)" /> : <Copy size={13} />}
                  <span>{copied ? 'Copied' : 'Copy'}</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
