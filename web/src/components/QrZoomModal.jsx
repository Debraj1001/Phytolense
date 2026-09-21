// web/src/components/QrZoomModal.jsx
import React, { useState, useEffect } from 'react';
import { useApp } from '../context/AppContext';
import QRCode from 'qrcode';
import { ZoomIn, ZoomOut, RotateCcw, Maximize2, Download, Copy, Check, X, Smartphone, Sparkles } from 'lucide-react';

export default function QrZoomModal() {
  const { qrZoomModalOpen, setQrZoomModalOpen, appConfig, showToast } = useApp();
  const [zoomLevel, setZoomLevel] = useState(1.8); // 1.8x default zoom in modal
  const [svgMarkup, setSvgMarkup] = useState('');
  const [copied, setCopied] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);

  // Target download URL configured by Admin (matches primary target selected)
  const androidUrl = appConfig?.download_url_android || 
    'https://github.com/Debraj1001/Phytolense/releases/download/v1.0.2/app-release.apk';
  const targetUrl = appConfig?.qr_primary_target === 'playstore' 
    ? (appConfig?.download_url_playstore || 'https://play.google.com/store/apps/details?id=com.phytolens.app')
    : appConfig?.qr_primary_target === 'ios'
    ? (appConfig?.download_url_ios || 'https://testflight.apple.com/join/phytolens')
    : appConfig?.qr_primary_target === 'web'
    ? (appConfig?.download_url_web || 'https://phytolens.agritech.org')
    : androidUrl;

  // Generate ultra-crisp vector SVG QR
  useEffect(() => {
    if (!targetUrl) return;

    QRCode.toString(targetUrl, {
      type: 'svg',
      errorCorrectionLevel: appConfig?.qr_error_correction || 'H',
      margin: 2,
      color: {
        dark: appConfig?.qr_foreground_color || '#0F172A',
        light: '#FFFFFF'
      }
    }, (err, svgString) => {
      if (!err && svgString) {
        setSvgMarkup(svgString);
      }
    });
  }, [targetUrl, appConfig]);

  if (!qrZoomModalOpen) return null;

  const handleCopyLink = () => {
    navigator.clipboard.writeText(targetUrl);
    setCopied(true);
    showToast('Download link copied to clipboard! 📋');
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownloadSvg = () => {
    const blob = new Blob([svgMarkup], { type: 'image/svg+xml;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'phytolens-app-qr-lossless.svg';
    link.click();
    URL.revokeObjectURL(url);
    showToast('Lossless vector SVG QR downloaded! 🌿');
  };

  const handleDownloadPng = async () => {
    try {
      const dataUrl = await QRCode.toDataURL(targetUrl, {
        width: 2048,
        margin: 2,
        errorCorrectionLevel: 'H',
        color: {
          dark: appConfig?.qr_foreground_color || '#0F172A',
          light: '#FFFFFF'
        }
      });
      const link = document.createElement('a');
      link.href = dataUrl;
      link.download = 'phytolens-app-qr-2048px.png';
      link.click();
      showToast('High-Res 2048x2048 PNG QR downloaded! 📸');
    } catch (err) {
      showToast('Error generating PNG: ' + err.message, 'error');
    }
  };

  return (
    <div className="modal-overlay" onClick={() => setQrZoomModalOpen(false)}>
      <div 
        className="neo-card" 
        onClick={(e) => e.stopPropagation()}
        style={{
          width: isFullscreen ? '96vw' : '100%',
          maxWidth: isFullscreen ? '1200px' : '680px',
          maxHeight: '94vh',
          backgroundColor: '#FFFFFF',
          padding: '24px',
          display: 'flex',
          flexDirection: 'column',
          gap: '16px',
          overflow: 'hidden'
        }}
      >
        {/* Top Header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span className="badge badge-emerald">Lossless Vector Precision</span>
              <span className="badge badge-amber">Error Correction Level H (30% redundancy)</span>
            </div>
            <h3 style={{ fontSize: '20px', marginTop: '6px' }}>
              Lossless High-Resolution QR Viewer
            </h3>
            <p style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
              Rendered via vector SVG. Zero pixelation at any zoom scale — 100% scan fidelity on any camera.
            </p>
          </div>

          <button 
            onClick={() => setQrZoomModalOpen(false)}
            className="btn btn-outline btn-sm"
            style={{ padding: '6px 8px' }}
          >
            <X size={18} />
          </button>
        </div>

        {/* Zoom Control Bar */}
        <div style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          flexWrap: 'wrap',
          gap: '12px',
          padding: '10px 16px',
          backgroundColor: 'var(--bg-subtle)',
          borderRadius: 'var(--radius-md)',
          border: 'var(--border-width-sm) solid var(--border-color)'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ fontSize: '13px', fontWeight: 700, fontFamily: 'var(--font-display)' }}>
              Zoom Level: {Math.round(zoomLevel * 100)}%
            </span>
            <input
              type="range"
              min="0.8"
              max="4.0"
              step="0.1"
              value={zoomLevel}
              onChange={(e) => setZoomLevel(parseFloat(e.target.value))}
              style={{ width: '130px', cursor: 'pointer', accentColor: 'var(--primary-dark)' }}
            />
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <button
              onClick={() => setZoomLevel(z => Math.max(0.8, Number((z - 0.2).toFixed(1))))}
              className="btn btn-white btn-sm"
              title="Zoom Out"
            >
              <ZoomOut size={14} />
            </button>
            <button
              onClick={() => setZoomLevel(1.0)}
              className="btn btn-white btn-sm"
              title="Reset 100%"
            >
              <RotateCcw size={14} />
              <span>1x</span>
            </button>
            <button
              onClick={() => setZoomLevel(z => Math.min(4.0, Number((z + 0.2).toFixed(1))))}
              className="btn btn-white btn-sm"
              title="Zoom In"
            >
              <ZoomIn size={14} />
            </button>
            <button
              onClick={() => setIsFullscreen(!isFullscreen)}
              className="btn btn-white btn-sm"
              title="Toggle Fullscreen"
            >
              <Maximize2 size={14} />
            </button>
          </div>
        </div>

        {/* QR Stage with Infinite Scaling */}
        <div 
          className="qr-zoom-stage"
          style={{
            height: isFullscreen ? '55vh' : '360px',
            position: 'relative'
          }}
        >
          <div 
            className="qr-zoom-svg-wrapper"
            style={{
              transform: `scale(${zoomLevel})`,
              width: '240px',
              height: '240px',
              backgroundColor: '#FFFFFF',
              borderRadius: '8px',
              padding: '12px',
              border: '2px solid #0F172A',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              position: 'relative'
            }}
            dangerouslySetInnerHTML={{ __html: svgMarkup }}
          />

          {/* Plant Icon in Center */}
          {appConfig?.qr_logo_enabled !== false && (
            <div style={{
              position: 'absolute',
              pointerEvents: 'none',
              transform: `scale(${zoomLevel})`,
              transformOrigin: 'center center',
              width: '38px',
              height: '38px',
              backgroundColor: '#10B981',
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

        {/* Target URL Info */}
        <div style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          backgroundColor: 'var(--bg-subtle)',
          padding: '10px 14px',
          borderRadius: 'var(--radius-md)',
          border: 'var(--border-width-sm) solid var(--border-color)',
          fontSize: '12px'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', overflow: 'hidden' }}>
            <Smartphone size={16} color="var(--primary-dark)" />
            <span style={{ fontWeight: 700 }}>Active Target:</span>
            <span style={{
              fontFamily: 'var(--font-mono)',
              color: 'var(--text-secondary)',
              textOverflow: 'ellipsis',
              overflow: 'hidden',
              whiteSpace: 'nowrap',
              maxWidth: '320px'
            }}>
              {targetUrl}
            </span>
          </div>

          <button
            onClick={handleCopyLink}
            className="btn btn-white btn-sm"
            style={{ padding: '4px 10px' }}
          >
            {copied ? <Check size={13} color="var(--primary-dark)" /> : <Copy size={13} />}
            <span>{copied ? 'Copied' : 'Copy'}</span>
          </button>
        </div>

        {/* Download Actions */}
        <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', flexWrap: 'wrap' }}>
          <button
            onClick={handleDownloadSvg}
            className="btn btn-white btn-sm"
          >
            <Download size={14} />
            <span>Download Lossless Vector (.SVG)</span>
          </button>
          <button
            onClick={handleDownloadPng}
            className="btn btn-primary btn-sm"
          >
            <Download size={14} />
            <span>Download Ultra-HD (.PNG 2048px)</span>
          </button>
        </div>
      </div>
    </div>
  );
}
