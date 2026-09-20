// web/src/components/Admin/QrManagerPage.jsx
import React, { useState, useEffect } from 'react';
import { useApp } from '../../context/AppContext';
import QRCode from 'qrcode';
import { QrCode, Save, ZoomIn, Smartphone, ExternalLink, Check, Sparkles, RefreshCw } from 'lucide-react';

export default function QrManagerPage() {
  const { appConfig, handleSaveAppConfig, setQrZoomModalOpen, showToast } = useApp();

  const [formData, setFormData] = useState({
    download_url_android: '',
    download_url_playstore: '',
    download_url_ios: '',
    download_url_web: '',
    qr_primary_target: 'android',
    qr_foreground_color: '#0F172A',
    qr_error_correction: 'H',
    qr_logo_enabled: true
  });

  const [svgPreview, setSvgPreview] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (appConfig) {
      setFormData({
        download_url_android: appConfig.download_url_android || 'https://github.com/Debraj1001/Phytolense/releases/latest/download/phytolens-release.apk',
        download_url_playstore: appConfig.download_url_playstore || 'https://play.google.com/store/apps/details?id=com.phytolens.app',
        download_url_ios: appConfig.download_url_ios || 'https://testflight.apple.com/join/phytolens',
        download_url_web: appConfig.download_url_web || 'https://phytolens.agritech.org',
        qr_primary_target: appConfig.qr_primary_target || 'android',
        qr_foreground_color: appConfig.qr_foreground_color || '#0F172A',
        qr_error_correction: appConfig.qr_error_correction || 'H',
        qr_logo_enabled: appConfig.qr_logo_enabled !== false
      });
    }
  }, [appConfig]);

  // Compute active target URL
  const activeTargetUrl = formData.qr_primary_target === 'playstore' 
    ? formData.download_url_playstore 
    : formData.qr_primary_target === 'ios'
    ? formData.download_url_ios
    : formData.qr_primary_target === 'web'
    ? formData.download_url_web
    : formData.download_url_android;

  // Generate live SVG QR preview
  useEffect(() => {
    if (!activeTargetUrl) return;

    QRCode.toString(activeTargetUrl, {
      type: 'svg',
      errorCorrectionLevel: formData.qr_error_correction,
      margin: 1,
      color: {
        dark: formData.qr_foreground_color,
        light: '#FFFFFF'
      }
    }, (err, str) => {
      if (!err && str) {
        setSvgPreview(str);
      }
    });
  }, [activeTargetUrl, formData.qr_foreground_color, formData.qr_error_correction]);

  const handleChange = (field, val) => {
    setFormData(prev => ({ ...prev, [field]: val }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await handleSaveAppConfig(formData);
    } finally {
      setSaving(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '28px' }}>
      {/* Top Header */}
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        flexWrap: 'wrap',
        gap: '16px'
      }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span className="badge badge-emerald">Public QR Generation</span>
            <span className="badge badge-mint">Live Public Page Sync</span>
          </div>
          <h1 style={{ fontSize: '30px', marginTop: '6px' }}>QR Code & App Download Manager</h1>
          <p style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>
            Configure the download URLs for Android, iOS, and Play Store. Setup the public QR code's destination and visual fidelity.
          </p>
        </div>

        <div style={{ display: 'flex', gap: '10px' }}>
          <button
            type="button"
            onClick={() => setQrZoomModalOpen(true)}
            className="btn btn-white btn-sm"
          >
            <ZoomIn size={14} />
            <span>Test Lossless Zoom 🔍</span>
          </button>

          <button
            type="submit"
            disabled={saving}
            className="btn btn-primary btn-sm"
            style={{ fontWeight: 800 }}
          >
            <Save size={16} />
            <span>{saving ? 'Saving...' : 'Save & Publish to Landing Page'}</span>
          </button>
        </div>
      </div>

      {/* Main Grid: Form Left, Live QR Preview Right */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
        gap: '24px'
      }}>
        {/* Left: Download URLs Setup */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          {/* Channel URLs Card */}
          <div className="neo-card" style={{ backgroundColor: '#FFFFFF' }}>
            <h3 style={{ fontSize: '18px', marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Smartphone size={18} />
              <span>App Download Distribution URLs</span>
            </h3>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                  🤖 Android Direct APK Download URL
                </label>
                <input
                  type="url"
                  required
                  value={formData.download_url_android}
                  onChange={(e) => handleChange('download_url_android', e.target.value)}
                  className="neo-input"
                  placeholder="https://.../phytolens-release.apk"
                />
                <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '2px' }}>
                  Direct APK file link. Recommended for rural growers.
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                  ▶️ Google Play Store URL
                </label>
                <input
                  type="url"
                  value={formData.download_url_playstore}
                  onChange={(e) => handleChange('download_url_playstore', e.target.value)}
                  className="neo-input"
                  placeholder="https://play.google.com/store/apps/details?id=..."
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                  🍏 iOS App Store / TestFlight URL
                </label>
                <input
                  type="url"
                  value={formData.download_url_ios}
                  onChange={(e) => handleChange('download_url_ios', e.target.value)}
                  className="neo-input"
                  placeholder="https://testflight.apple.com/join/..."
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                  🌐 Web App PWA URL
                </label>
                <input
                  type="url"
                  value={formData.download_url_web}
                  onChange={(e) => handleChange('download_url_web', e.target.value)}
                  className="neo-input"
                  placeholder="https://phytolens.agritech.org"
                />
              </div>
            </div>
          </div>

          {/* QR Visual Customization Card */}
          <div className="neo-card" style={{ backgroundColor: '#FFFFFF' }}>
            <h3 style={{ fontSize: '18px', marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <QrCode size={18} />
              <span>QR Code Encoding & Visual Appearance</span>
            </h3>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                  Primary Target Link for Public QR Code
                </label>
                <select
                  value={formData.qr_primary_target}
                  onChange={(e) => handleChange('qr_primary_target', e.target.value)}
                  className="neo-input neo-select"
                >
                  <option value="android">Android Direct APK (Recommended for Farmers)</option>
                  <option value="playstore">Google Play Store</option>
                  <option value="ios">Apple iOS TestFlight</option>
                  <option value="web">Web PWA Portal</option>
                </select>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                    Error Correction Level
                  </label>
                  <select
                    value={formData.qr_error_correction}
                    onChange={(e) => handleChange('qr_error_correction', e.target.value)}
                    className="neo-input neo-select"
                  >
                    <option value="L">L (7% redundant)</option>
                    <option value="M">M (15% redundant)</option>
                    <option value="Q">Q (25% redundant)</option>
                    <option value="H">H (30% ultra-redundant)</option>
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '4px' }}>
                    QR Dark Color
                  </label>
                  <div style={{ display: 'flex', gap: '6px' }}>
                    <input
                      type="color"
                      value={formData.qr_foreground_color}
                      onChange={(e) => handleChange('qr_foreground_color', e.target.value)}
                      style={{ width: '42px', height: '38px', borderRadius: '6px', border: '2px solid #0F172A', cursor: 'pointer' }}
                    />
                    <input
                      type="text"
                      value={formData.qr_foreground_color}
                      onChange={(e) => handleChange('qr_foreground_color', e.target.value)}
                      className="neo-input"
                      style={{ flex: 1 }}
                    />
                  </div>
                </div>
              </div>

              <div>
                <label style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer', fontSize: '13px', fontWeight: 600 }}>
                  <input
                    type="checkbox"
                    checked={formData.qr_logo_enabled}
                    onChange={(e) => handleChange('qr_logo_enabled', e.target.checked)}
                    style={{ width: '18px', height: '18px', accentColor: 'var(--primary)' }}
                  />
                  <span>Render Botanical Emblem (🌿) in Center of QR</span>
                </label>
              </div>
            </div>
          </div>
        </div>

        {/* Right: Live Interactive QR Preview */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div className="neo-card" style={{ backgroundColor: '#FFFFFF', textAlign: 'center', padding: '28px' }}>
            <div style={{ display: 'flex', justifyContent: 'center', marginBottom: '8px' }}>
              <span className="badge badge-emerald">Live Output on Public Page</span>
            </div>
            <h3 style={{ fontSize: '20px', marginBottom: '4px' }}>Live QR Code Preview</h3>
            <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginBottom: '20px' }}>
              This exact SVG renders on the public landing page. Point your mobile phone camera right now to test scan!
            </p>

            <div style={{
              display: 'inline-flex',
              padding: '16px',
              backgroundColor: '#FFFFFF',
              borderRadius: 'var(--radius-lg)',
              border: '3px solid #0F172A',
              boxShadow: 'var(--shadow-lg)',
              position: 'relative',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <div 
                style={{ width: '220px', height: '220px' }}
                dangerouslySetInnerHTML={{ __html: svgPreview }}
              />

              {formData.qr_logo_enabled && (
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
                  boxShadow: '0 2px 4px rgba(0,0,0,0.2)'
                }}>
                  🌿
                </div>
              )}
            </div>

            <div style={{
              marginTop: '20px',
              padding: '10px 14px',
              backgroundColor: 'var(--bg-subtle)',
              borderRadius: 'var(--radius-md)',
              border: '1.5px solid #0F172A',
              fontSize: '12px',
              textAlign: 'left'
            }}>
              <div style={{ fontWeight: 700, marginBottom: '2px' }}>Encoded Destination Link:</div>
              <div style={{
                fontFamily: 'var(--font-mono)',
                fontSize: '11px',
                color: 'var(--text-secondary)',
                wordBreak: 'break-all'
              }}>
                {activeTargetUrl}
              </div>
            </div>

            <button
              type="button"
              onClick={() => setQrZoomModalOpen(true)}
              className="btn btn-dark"
              style={{ width: '100%', marginTop: '16px', justifyContent: 'center' }}
            >
              <ZoomIn size={16} />
              <span>Launch Lossless Zooming Modal 🔍</span>
            </button>
          </div>
        </div>
      </div>
    </form>
  );
}
