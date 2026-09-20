// web/src/App.jsx
import React from 'react';
import { AppProvider, useApp } from './context/AppContext';
import Navbar from './components/Navbar';
import AdminLoginModal from './components/AdminLoginModal';
import QrZoomModal from './components/QrZoomModal';

// Landing Page Sections
import Hero from './components/LandingPage/Hero';
import CrisisSolution from './components/LandingPage/CrisisSolution';
import AppShowcase from './components/LandingPage/AppShowcase';
import QrDownloadSection from './components/LandingPage/QrDownloadSection';
import TechSpecs from './components/LandingPage/TechSpecs';
import Footer from './components/LandingPage/Footer';

// Admin Components
import AdminLayout from './components/Admin/AdminLayout';
import DashboardPage from './components/Admin/DashboardPage';
import AppConfigPage from './components/Admin/AppConfigPage';
import AiUsagePage from './components/Admin/AiUsagePage';
import UserManagementPage from './components/Admin/UserManagementPage';
import QrManagerPage from './components/Admin/QrManagerPage';
import FieldTelemetryPage from './components/Admin/FieldTelemetryPage';

function AppContent() {
  const { currentView, adminSubPage, toast } = useApp();

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      {/* Toast Notification Manager */}
      {toast && (
        <div className="toast-container">
          <div 
            className="toast"
            style={{
              borderColor: toast.type === 'error' ? 'var(--accent-red)' : 'var(--border-color)',
              backgroundColor: toast.type === 'error' ? 'var(--accent-red-tint)' : '#FFFFFF'
            }}
          >
            <span>{toast.type === 'error' ? '⚠️' : '🌿'}</span>
            <span>{toast.message}</span>
          </div>
        </div>
      )}

      {/* Global Modals */}
      <AdminLoginModal />
      <QrZoomModal />

      {/* View Routing */}
      {currentView === 'landing' ? (
        <>
          <Navbar />
          <main style={{ flex: 1 }}>
            <Hero />
            <CrisisSolution />
            <AppShowcase />
            <QrDownloadSection />
            <TechSpecs />
          </main>
          <Footer />
        </>
      ) : (
        <AdminLayout>
          {adminSubPage === 'dashboard' && <DashboardPage />}
          {adminSubPage === 'config' && <AppConfigPage />}
          {adminSubPage === 'ai_usage' && <AiUsagePage />}
          {adminSubPage === 'users' && <UserManagementPage />}
          {adminSubPage === 'qr_manager' && <QrManagerPage />}
          {adminSubPage === 'field_telemetry' && <FieldTelemetryPage />}
        </AdminLayout>
      )}
    </div>
  );
}

export default function App() {
  return (
    <AppProvider>
      <AppContent />
    </AppProvider>
  );
}
