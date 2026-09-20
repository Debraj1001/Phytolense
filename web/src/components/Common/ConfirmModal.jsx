// web/src/components/Common/ConfirmModal.jsx
import React, { useState, useEffect } from 'react';
import { AlertTriangle, Trash2, UserX, UserCheck, ShieldAlert, CheckCircle2, X, Loader2 } from 'lucide-react';

export default function ConfirmModal({
  isOpen,
  onClose,
  onConfirm,
  title,
  message,
  confirmText = 'Confirm',
  cancelText = 'Cancel',
  variant = 'danger', // 'danger' | 'warning' | 'primary' | 'emerald'
  icon = null
}) {
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    const handleKeyDown = (e) => {
      if (!isOpen) return;
      if (e.key === 'Escape' && !isSubmitting) {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, isSubmitting, onClose]);

  if (!isOpen) return null;

  const handleConfirm = async () => {
    if (isSubmitting) return; // Prevent double click
    setIsSubmitting(true);
    try {
      await onConfirm();
      onClose();
    } catch (err) {
      console.error('Confirmation action error:', err);
    } finally {
      setIsSubmitting(false);
    }
  };

  const getVariantStyles = () => {
    switch (variant) {
      case 'danger':
        return {
          badgeBg: '#FEE2E2',
          badgeColor: '#991B1B',
          borderColor: '#EF4444',
          btnBg: '#EF4444',
          btnColor: '#FFFFFF',
          defaultIcon: <Trash2 size={24} color="#EF4444" />
        };
      case 'warning':
        return {
          badgeBg: '#FEF3C7',
          badgeColor: '#92400E',
          borderColor: '#F59E0B',
          btnBg: '#F59E0B',
          btnColor: '#0F172A',
          defaultIcon: <AlertTriangle size={24} color="#D97706" />
        };
      case 'emerald':
      case 'success':
        return {
          badgeBg: '#D1FAE5',
          badgeColor: '#065F46',
          borderColor: '#10B981',
          btnBg: '#10B981',
          btnColor: '#FFFFFF',
          defaultIcon: <CheckCircle2 size={24} color="#10B981" />
        };
      default: // primary
        return {
          badgeBg: 'var(--primary-tint)',
          badgeColor: 'var(--primary-dark)',
          borderColor: 'var(--primary)',
          btnBg: 'var(--primary)',
          btnColor: '#0F172A',
          defaultIcon: <ShieldAlert size={24} color="var(--primary-dark)" />
        };
    }
  };

  const styles = getVariantStyles();

  return (
    <div 
      className="modal-overlay" 
      onClick={() => !isSubmitting && onClose()}
      style={{
        position: 'fixed',
        inset: 0,
        backgroundColor: 'rgba(15, 23, 42, 0.65)',
        backdropFilter: 'blur(4px)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 9999,
        padding: '16px'
      }}
    >
      <div
        className="neo-card"
        onClick={(e) => e.stopPropagation()}
        style={{
          maxWidth: '480px',
          width: '100%',
          backgroundColor: '#FFFFFF',
          border: '3px solid #0F172A',
          boxShadow: '6px 6px 0px #0F172A',
          borderRadius: '16px',
          padding: '28px',
          animation: 'modalSlideUp 0.18s ease-out'
        }}
      >
        {/* Header Icon + Close */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '18px' }}>
          <div style={{
            width: '48px',
            height: '48px',
            borderRadius: '12px',
            backgroundColor: styles.badgeBg,
            border: '2px solid #0F172A',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: '2px 2px 0px #0F172A'
          }}>
            {icon || styles.defaultIcon}
          </div>

          {!isSubmitting && (
            <button
              onClick={onClose}
              disabled={isSubmitting}
              style={{
                background: 'none',
                border: '2px solid #0F172A',
                borderRadius: '8px',
                padding: '4px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                backgroundColor: '#F8FAFC'
              }}
            >
              <X size={18} />
            </button>
          )}
        </div>

        {/* Title & Message */}
        <h3 style={{
          fontSize: '20px',
          fontWeight: 800,
          fontFamily: 'var(--font-display)',
          marginBottom: '8px',
          color: '#0F172A'
        }}>
          {title}
        </h3>

        <div style={{
          fontSize: '14px',
          color: 'var(--text-secondary)',
          lineHeight: 1.55,
          marginBottom: '24px'
        }}>
          {message}
        </div>

        {/* Action Buttons with double-click prevention */}
        <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
          <button
            type="button"
            onClick={onClose}
            disabled={isSubmitting}
            className="btn btn-white"
            style={{
              padding: '10px 18px',
              fontSize: '13px',
              fontWeight: 700,
              opacity: isSubmitting ? 0.5 : 1,
              cursor: isSubmitting ? 'not-allowed' : 'pointer'
            }}
          >
            {cancelText}
          </button>

          <button
            type="button"
            onClick={handleConfirm}
            disabled={isSubmitting}
            className="btn"
            style={{
              backgroundColor: styles.btnBg,
              color: styles.btnColor,
              borderColor: '#0F172A',
              padding: '10px 20px',
              fontSize: '13px',
              fontWeight: 800,
              display: 'inline-flex',
              alignItems: 'center',
              gap: '8px',
              opacity: isSubmitting ? 0.7 : 1,
              cursor: isSubmitting ? 'not-allowed' : 'pointer',
              boxShadow: isSubmitting ? 'none' : '3px 3px 0px #0F172A',
              transform: isSubmitting ? 'translate(2px, 2px)' : 'none'
            }}
          >
            {isSubmitting && <Loader2 size={16} className="animate-spin" />}
            <span>{isSubmitting ? 'Processing...' : confirmText}</span>
          </button>
        </div>
      </div>
    </div>
  );
}
