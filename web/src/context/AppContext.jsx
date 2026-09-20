// web/src/context/AppContext.jsx
import React, { createContext, useContext, useState, useEffect } from 'react';
import {
  fetchAppConfig,
  saveAppConfig as apiSaveAppConfig,
  fetchUsersList,
  updateUserRecord,
  deleteUserRecord,
  fetchAiUsageList,
  updateAiUsageRecord,
  resetUserDailyAi as apiResetUserDailyAi,
  fetchOutbreaks,
  fetchRetailers,
  fetchScansList,
  fetchPaymentsList,
  authenticateAdmin,
  supabase,
  supabaseAdmin,
  DESIGNATED_ADMIN_EMAIL,
  DESIGNATED_ADMIN_UID
} from '../services/supabase';

const AppContext = createContext();

export function AppProvider({ children }) {
  // Navigation State: 'landing' or 'admin'
  const [currentView, setCurrentView] = useState('landing');
  const [adminSubPage, setAdminSubPage] = useState('dashboard');

  // Admin Auth State
  const [adminUser, setAdminUser] = useState(() => {
    try {
      const saved = localStorage.getItem('phytolens_admin_user');
      return saved ? JSON.parse(saved) : null;
    } catch {
      return null;
    }
  });
  const [loginModalOpen, setLoginModalOpen] = useState(false);

  // Data State - Actual Database Tables
  const [appConfig, setAppConfig] = useState(null);
  const [users, setUsers] = useState([]);
  const [aiUsage, setAiUsage] = useState([]);
  const [scans, setScans] = useState([]);
  const [payments, setPayments] = useState([]);
  const [outbreaks, setOutbreaks] = useState([]);
  const [retailers, setRetailers] = useState([]);
  const [loading, setLoading] = useState(true);

  // Modals & Overlays
  const [qrZoomModalOpen, setQrZoomModalOpen] = useState(false);
  const [toast, setToast] = useState(null);

  const showToast = (message, type = 'success') => {
    setToast({ message, type });
    setTimeout(() => {
      setToast(null);
    }, 3800);
  };

  // Initial Load from Supabase Database
  const loadData = async () => {
    setLoading(true);
    try {
      const [cfg, userList, usageList, alerts, shops, scanList, paymentList] = await Promise.all([
        fetchAppConfig(),
        fetchUsersList(),
        fetchAiUsageList(),
        fetchOutbreaks(),
        fetchRetailers(),
        fetchScansList(),
        fetchPaymentsList()
      ]);
      setAppConfig(cfg);
      setUsers(userList);
      setAiUsage(usageList);
      setOutbreaks(alerts);
      setRetailers(shops);
      setScans(scanList);
      setPayments(paymentList);
    } catch (err) {
      console.error('Error loading application data:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();

    // ─── Realtime Subscriptions for Admin Portal & Public Pages ────────────
    const configChannel = supabase
      .channel('public_realtime_config')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'app_config' },
        (payload) => {
          if (payload.new) {
            setAppConfig(prev => ({ ...prev, ...payload.new }));
          }
        }
      )
      .subscribe();

    const usersChannel = supabaseAdmin
      .channel('admin_realtime_users')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'users' },
        (payload) => {
          const isUserAdmin = payload.new?.email?.toLowerCase().trim() === DESIGNATED_ADMIN_EMAIL.toLowerCase().trim();
          if (isUserAdmin) return;

          if (payload.eventType === 'INSERT') {
            setUsers(prev => [payload.new, ...prev.filter(u => u.uid !== payload.new.uid)]);
          } else if (payload.eventType === 'UPDATE') {
            setUsers(prev => prev.map(u => (u.uid === payload.new.uid ? { ...u, ...payload.new } : u)));
          } else if (payload.eventType === 'DELETE') {
            setUsers(prev => prev.filter(u => u.uid !== payload.old?.uid));
          }
        }
      )
      .subscribe();

    const aiUsageChannel = supabaseAdmin
      .channel('admin_realtime_ai')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'ai_usage' },
        (payload) => {
          if (payload.eventType === 'INSERT') {
            setAiUsage(prev => [payload.new, ...prev]);
          } else if (payload.eventType === 'UPDATE') {
            setAiUsage(prev => prev.map(a => (a.id === payload.new.id ? { ...a, ...payload.new } : a)));
          } else if (payload.eventType === 'DELETE') {
            setAiUsage(prev => prev.filter(a => a.id !== payload.old?.id));
          }
        }
      )
      .subscribe();

    const scansChannel = supabaseAdmin
      .channel('admin_realtime_scans')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'scans' },
        () => {
          fetchScansList().then(setScans);
        }
      )
      .subscribe();

    const paymentsChannel = supabaseAdmin
      .channel('admin_realtime_payments')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'payments' },
        (payload) => {
          if (payload.eventType === 'INSERT') {
            setPayments(prev => [payload.new, ...prev]);
          } else if (payload.eventType === 'UPDATE') {
            setPayments(prev => prev.map(p => (p.id === payload.new.id ? { ...p, ...payload.new } : p)));
          } else if (payload.eventType === 'DELETE') {
            setPayments(prev => prev.filter(p => p.id !== payload.old?.id));
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(configChannel);
      supabaseAdmin.removeChannel(usersChannel);
      supabaseAdmin.removeChannel(aiUsageChannel);
      supabaseAdmin.removeChannel(scansChannel);
      supabaseAdmin.removeChannel(paymentsChannel);
    };
  }, []);

  // Admin Actions
  const handleAdminLogin = async (email, password) => {
    const res = await authenticateAdmin(email, password);
    if (res.success) {
      setAdminUser(res.user);
      localStorage.setItem('phytolens_admin_user', JSON.stringify(res.user));
      setLoginModalOpen(false);
      setCurrentView('admin');
      showToast(`Welcome Admin ${res.user.display_name || res.user.email}! ⚡`);
      return { success: true };
    } else {
      showToast(res.error || 'Authentication failed', 'error');
      return { success: false, error: res.error };
    }
  };

  const handleAdminLogout = () => {
    setAdminUser(null);
    localStorage.removeItem('phytolens_admin_user');
    setCurrentView('landing');
    showToast('Admin signed out safely.');
  };

  // App Config update
  const handleSaveAppConfig = async (updatedFields) => {
    const res = await apiSaveAppConfig(updatedFields);
    if (res.success) {
      setAppConfig(prev => ({ ...prev, ...updatedFields }));
      showToast('App configuration saved to database! 🌿');
      return true;
    } else {
      showToast('Failed to save config: ' + res.error, 'error');
      return false;
    }
  };

  // User management updates
  const handleUpdateUser = async (uid, updates) => {
    const res = await updateUserRecord(uid, updates);
    if (res.success) {
      setUsers(prev => prev.map(u => (u.uid === uid ? { ...u, ...updates } : u)));
      showToast('User record updated in Supabase! ✨');
      return true;
    } else {
      showToast('User update error: ' + res.error, 'error');
      return false;
    }
  };

  const handleDeleteUser = async (uid) => {
    const res = await deleteUserRecord(uid);
    if (res.success) {
      setUsers(prev => prev.filter(u => u.uid !== uid));
      showToast('User removed from database.');
      return true;
    } else {
      showToast('Delete failed: ' + res.error, 'error');
      return false;
    }
  };

  // AI usage management updates
  const handleUpdateAiUsage = async (id, updates) => {
    const res = await updateAiUsageRecord(id, updates);
    if (res.success) {
      setAiUsage(prev => prev.map(a => (a.id === id ? { ...a, ...updates } : a)));
      showToast('AI log entry updated.');
      return true;
    } else {
      showToast('AI update error: ' + res.error, 'error');
      return false;
    }
  };

  const handleResetUserAi = async (userId) => {
    const res = await apiResetUserDailyAi(userId);
    if (res.success) {
      setUsers(prev => prev.map(u => (u.uid === userId ? { ...u, daily_ai_count: 0 } : u)));
      showToast(`Daily AI count reset for user ${userId.substring(0, 8)}...`);
      return true;
    } else {
      showToast('Reset failed: ' + res.error, 'error');
      return false;
    }
  };

  return (
    <AppContext.Provider
      value={{
        currentView,
        setCurrentView,
        adminSubPage,
        setAdminSubPage,
        adminUser,
        loginModalOpen,
        setLoginModalOpen,
        handleAdminLogin,
        handleAdminLogout,
        appConfig,
        handleSaveAppConfig,
        users,
        handleUpdateUser,
        handleDeleteUser,
        aiUsage,
        handleUpdateAiUsage,
        handleResetUserAi,
        scans,
        payments,
        outbreaks,
        retailers,
        loading,
        refreshData: loadData,
        qrZoomModalOpen,
        setQrZoomModalOpen,
        toast,
        showToast,
        DESIGNATED_ADMIN_EMAIL,
        DESIGNATED_ADMIN_UID
      }}
    >
      {children}
    </AppContext.Provider>
  );
}

export function useApp() {
  return useContext(AppContext);
}
