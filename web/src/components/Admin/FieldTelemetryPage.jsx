// web/src/components/Admin/FieldTelemetryPage.jsx
import React, { useState } from 'react';
import { useApp } from '../../context/AppContext';
import { Radio, Store, MapPin, Phone, Star, AlertTriangle, Plus, ShieldCheck } from 'lucide-react';

export default function FieldTelemetryPage() {
  const { outbreaks, retailers } = useApp();

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '28px' }}>
      <div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span className="badge badge-red">Community Radar</span>
          <span className="badge badge-emerald">B2B Verified Network</span>
        </div>
        <h1 style={{ fontSize: '30px', marginTop: '6px' }}>Field Telemetry & Agro-Retailers</h1>
        <p style={{ fontSize: '14px', color: 'var(--text-secondary)' }}>
          Review crowdsourced 10 km disease outbreak clusters and certified local agricultural input suppliers.
        </p>
      </div>

      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
        gap: '24px'
      }}>
        {/* Outbreaks List */}
        <div className="neo-card" style={{ backgroundColor: '#FFFFFF' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '16px' }}>
            <Radio size={20} color="var(--accent-red)" />
            <h3 style={{ fontSize: '18px' }}>Active Disease Outbreaks ({outbreaks.length})</h3>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {outbreaks.length === 0 ? (
              <div style={{ padding: '16px', textAlign: 'center', color: 'var(--text-muted)' }}>
                No active outbreak alerts reported in database.
              </div>
            ) : (
              outbreaks.map((alert, i) => (
                <div key={alert.id || i} style={{
                  padding: '12px 14px',
                  backgroundColor: 'var(--accent-red-tint)',
                  borderRadius: 'var(--radius-md)',
                  border: '1.5px solid var(--border-color)',
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center'
                }}>
                  <div>
                    <div style={{ fontWeight: 800, fontSize: '14px', color: '#991B1B' }}>
                      {alert.disease_name}
                    </div>
                    <div style={{ fontSize: '11px', color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', gap: '4px', marginTop: '2px' }}>
                      <MapPin size={12} />
                      <span>Lat: {alert.lat} · Lon: {alert.lon}</span>
                    </div>
                  </div>
                  <span className="badge badge-red" style={{ fontSize: '10px' }}>
                    {alert.severity || 'ALERT'}
                  </span>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Certified Retailers */}
        <div className="neo-card" style={{ backgroundColor: '#FFFFFF' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '16px' }}>
            <Store size={20} color="var(--primary-dark)" />
            <h3 style={{ fontSize: '18px' }}>Verified Input Centers ({retailers.length})</h3>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {retailers.length === 0 ? (
              <div style={{ padding: '16px', textAlign: 'center', color: 'var(--text-muted)' }}>
                No retailers listed in database.
              </div>
            ) : (
              retailers.map((shop, i) => (
                <div key={shop.id || i} style={{
                  padding: '12px 14px',
                  backgroundColor: 'var(--bg-subtle)',
                  borderRadius: 'var(--radius-md)',
                  border: '1.5px solid var(--border-color)'
                }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                    <div>
                      <div style={{ fontWeight: 800, fontSize: '14px' }}>
                        {shop.name}
                      </div>
                      <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                        {shop.address}
                      </div>
                      {shop.phone && (
                        <div style={{ fontSize: '11px', color: 'var(--primary-dark)', fontWeight: 700, marginTop: '4px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                          <Phone size={12} />
                          <span>{shop.phone}</span>
                        </div>
                      )}
                    </div>
                    {shop.rating != null && (
                      <div style={{ display: 'flex', alignItems: 'center', gap: '4px', backgroundColor: '#FEF3C7', padding: '4px 8px', borderRadius: '6px', border: '1px solid #0F172A', fontSize: '11px', fontWeight: 800 }}>
                        <Star size={12} fill="#D97706" color="#D97706" />
                        <span>{shop.rating}</span>
                      </div>
                    )}
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
