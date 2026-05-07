import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { projectsApi, tasksApi, installationsApi, purchaseRequestsApi } from '../api';
import UserStatusCard from '../components/UserStatusCard';

const Dashboard = () => {
  const { user, isManager, logout } = useAuth();
  const [stats, setStats] = useState({
    projects: 0,
    tasks: 0,
    installations: 0,
    pendingRequests: 0
  });
  const [tasks, setTasks] = useState([]);
  const [installations, setInstallations] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadStats();
  }, []);

  const loadStats = async () => {
    try {
      const [projectsRes, tasksRes, installationsRes, requestsRes] = await Promise.all([
        projectsApi.getAll(),
        tasksApi.getAll(),
        installationsApi.getAll(),
        purchaseRequestsApi.getAll()
      ]);

      const tasksData = tasksRes.tasks || [];
      const installationsData = installationsRes.installations || [];

      setTasks(tasksData);
      setInstallations(installationsData);

      setStats({
        projects: projectsRes.projects?.length || 0,
        tasks: tasksData.length,
        installations: installationsData.length,
        pendingRequests: requestsRes.purchaseRequests?.filter(r => r.status === 'pending').length || 0
      });
    } catch (error) {
      console.error('Error loading stats:', error);
    } finally {
      setLoading(false);
    }
  };

  const getTaskStatusCounts = () => {
    const counts = {
      new: 0,
      planned: 0,
      in_progress: 0,
      waiting_materials: 0,
      done: 0,
      postponed: 0
    };
    tasks.forEach(task => {
      if (counts.hasOwnProperty(task.status)) {
        counts[task.status]++;
      }
    });
    return counts;
  };

  const getInstallationStatusCounts = () => {
    const counts = {
      new: 0,
      planned: 0,
      in_progress: 0,
      waiting_materials: 0,
      done: 0,
      postponed: 0
    };
    installations.forEach(inst => {
      if (counts.hasOwnProperty(inst.status)) {
        counts[inst.status]++;
      }
    });
    return counts;
  };

  const calculateProgress = () => {
    const totalTasks = tasks.length;
    const totalInstallations = installations.length;
    const total = totalTasks + totalInstallations;
    
    if (total === 0) return 0;
    
    const completedTasks = tasks.filter(t => t.status === 'done').length;
    const completedInstallations = installations.filter(i => i.status === 'done').length;
    const completed = completedTasks + completedInstallations;
    
    return Math.round((completed / total) * 100);
  };

  const taskStatusCounts = getTaskStatusCounts();
  const installationStatusCounts = getInstallationStatusCounts();
  const overallProgress = calculateProgress();

  const getStatusLabel = (status) => {
    const labels = {
      new: 'РќРѕРІР°СЏ',
      planned: 'Р—Р°РїР»Р°РЅРёСЂРѕРІР°РЅР°',
      in_progress: 'Р’ СЂР°Р±РѕС‚Рµ',
      waiting_materials: 'РћР¶РёРґР°РµС‚ РјР°С‚РµСЂРёР°Р»РѕРІ',
      done: 'Р’С‹РїРѕР»РЅРµРЅР°',
      postponed: 'РћС‚Р»РѕР¶РµРЅР°'
    };
    return labels[status] || status;
  };

  const getInstallationStatusLabel = (status) => {
    const labels = {
      new: 'РќРѕРІС‹Р№',
      planned: 'Р—Р°РїР»Р°РЅРёСЂРѕРІР°РЅ',
      in_progress: 'Р’ СЂР°Р±РѕС‚Рµ',
      waiting_materials: 'РћР¶РёРґР°РµС‚ РјР°С‚РµСЂРёР°Р»РѕРІ',
      done: 'Р—Р°РІРµСЂС€С‘РЅ',
      postponed: 'РћС‚Р»РѕР¶РµРЅ'
    };
    return labels[status] || status;
  };

  if (loading) {
    return <div className="loading">Р—Р°РіСЂСѓР·РєР°...</div>;
  }

  return (
    <div>
      <header className="header">
        <h1>РЎРёСЃС‚РµРјР° СѓРїСЂР°РІР»РµРЅРёСЏ Р·Р°РґР°С‡Р°РјРё</h1>
        <nav className="header-nav">
          <Link to="/">Р“Р»Р°РІРЅР°СЏ</Link>
          <Link to="/messenger">Р§Р°С‚С‹</Link>
          <Link to="/projects">РџСЂРѕРµРєС‚С‹</Link>
          <Link to="/tasks">Р—Р°РґР°С‡Рё</Link>
          <Link to="/installations">РњРѕРЅС‚Р°Р¶Рё</Link>
          <Link to="/purchase-requests">Р—Р°СЏРІРєРё</Link>
        </nav>
        <div className="header-user">
          <span>{user.name} ({user.role === 'manager' ? 'Р СѓРєРѕРІРѕРґРёС‚РµР»СЊ' : 'РСЃРїРѕР»РЅРёС‚РµР»СЊ'})</span>
          <button onClick={logout}>Р’С‹Р№С‚Рё</button>
        </div>
      </header>

      <main className="container">
        <h2 style={{ marginBottom: '20px' }}>Р”РѕР±СЂРѕ РїРѕР¶Р°Р»РѕРІР°С‚СЊ, {user.name}!</h2>

        <div className="stats-grid">
          <div className="stat-card">
            <h3>{stats.projects}</h3>
            <p>РџСЂРѕРµРєС‚РѕРІ</p>
            <Link to="/projects" className="btn btn-primary" style={{ marginTop: '10px', display: 'inline-block' }}>
              РџРѕРґСЂРѕР±РЅРµРµ
            </Link>
          </div>

          <div className="stat-card">
            <h3>{stats.tasks}</h3>
            <p>Р—Р°РґР°С‡</p>
            <Link to="/tasks" className="btn btn-primary" style={{ marginTop: '10px', display: 'inline-block' }}>
              РџРѕРґСЂРѕР±РЅРµРµ
            </Link>
          </div>

          <div className="stat-card">
            <h3>{stats.installations}</h3>
            <p>РњРѕРЅС‚Р°Р¶РµР№</p>
            <Link to="/installations" className="btn btn-primary" style={{ marginTop: '10px', display: 'inline-block' }}>
              РџРѕРґСЂРѕР±РЅРµРµ
            </Link>
          </div>

          <div className="stat-card">
            <h3>{stats.pendingRequests}</h3>
            <p>РћР¶РёРґР°СЋС‰РёС… Р·Р°СЏРІРѕРє</p>
            <Link to="/purchase-requests" className="btn btn-primary" style={{ marginTop: '10px', display: 'inline-block' }}>
              РџРѕРґСЂРѕР±РЅРµРµ
            </Link>
          </div>
</div>

        {/* User Status Card - Shows online/offline users with real-time updates */}
        <UserStatusCard />

        {/* Progress Bar Section */}
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">РћР±С‰РµРµ РІС‹РїРѕР»РЅРµРЅРёРµ</h3>
          </div>
          <div className="progress-container">
            <div className="progress-bar">
              <div 
                className="progress-fill" 
                style={{ width: `${overallProgress}%` }}
              ></div>
            </div>
            <div className="progress-text">
              <span>{overallProgress}% РІС‹РїРѕР»РЅРµРЅРѕ</span>
              <span>
                {tasks.filter(t => t.status === 'done').length + installations.filter(i => i.status === 'done').length} РёР· {tasks.length + installations.length} Р·Р°РІРµСЂС€РµРЅРѕ
              </span>
            </div>
          </div>
        </div>

        {/* Installation Status Breakdown */}
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">РЎС‚Р°С‚СѓСЃС‹ РјРѕРЅС‚Р°Р¶РµР№</h3>
          </div>
          <div className="status-breakdown">
            <div className="status-item">
              <span className="status-badge status-new">{getInstallationStatusLabel('new')}</span>
              <div className="status-bar-container">
                <div 
                  className="status-bar status-new" 
                  style={{ width: `${stats.installations > 0 ? (installationStatusCounts.new / stats.installations) * 100 : 0}%` }}
                ></div>
              </div>
              <span className="status-count">{installationStatusCounts.new}</span>
            </div>
            <div className="status-item">
              <span className="status-badge status-planned">{getInstallationStatusLabel('planned')}</span>
              <div className="status-bar-container">
                <div 
                  className="status-bar status-planned" 
                  style={{ width: `${stats.installations > 0 ? (installationStatusCounts.planned / stats.installations) * 100 : 0}%` }}
                ></div>
              </div>
              <span className="status-count">{installationStatusCounts.planned}</span>
            </div>
            <div className="status-item">
              <span className="status-badge status-in_progress">{getInstallationStatusLabel('in_progress')}</span>
              <div className="status-bar-container">
                <div 
                  className="status-bar status-in_progress" 
                  style={{ width: `${stats.installations > 0 ? (installationStatusCounts.in_progress / stats.installations) * 100 : 0}%` }}
                ></div>
              </div>
              <span className="status-count">{installationStatusCounts.in_progress}</span>
            </div>
            <div className="status-item">
              <span className="status-badge status-waiting_materials">{getInstallationStatusLabel('waiting_materials')}</span>
              <div className="status-bar-container">
                <div 
                  className="status-bar status-waiting_materials" 
                  style={{ width: `${stats.installations > 0 ? (installationStatusCounts.waiting_materials / stats.installations) * 100 : 0}%` }}
                ></div>
              </div>
              <span className="status-count">{installationStatusCounts.waiting_materials}</span>
            </div>
            <div className="status-item">
              <span className="status-badge status-done">{getInstallationStatusLabel('done')}</span>
              <div className="status-bar-container">
                <div 
                  className="status-bar status-done" 
                  style={{ width: `${stats.installations > 0 ? (installationStatusCounts.done / stats.installations) * 100 : 0}%` }}
                ></div>
              </div>
              <span className="status-count">{installationStatusCounts.done}</span>
            </div>
            <div className="status-item">
              <span className="status-badge status-postponed">{getInstallationStatusLabel('postponed')}</span>
              <div className="status-bar-container">
                <div 
                  className="status-bar status-postponed" 
                  style={{ width: `${stats.installations > 0 ? (installationStatusCounts.postponed / stats.installations) * 100 : 0}%` }}
                ></div>
              </div>
              <span className="status-count">{installationStatusCounts.postponed}</span>
            </div>
          </div>
        </div>

        {isManager && (
          <div className="card">
            <div className="card-header">
              <h3 className="card-title">Р‘С‹СЃС‚СЂС‹Рµ РґРµР№СЃС‚РІРёСЏ</h3>
            </div>
            <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
              <Link to="/projects" className="btn btn-primary">РЎРѕР·РґР°С‚СЊ РїСЂРѕРµРєС‚</Link>
              <Link to="/tasks" className="btn btn-primary">РЎРѕР·РґР°С‚СЊ Р·Р°РґР°С‡Сѓ</Link>
              <Link to="/installations" className="btn btn-primary">РЎРѕР·РґР°С‚СЊ РјРѕРЅС‚Р°Р¶</Link>
            </div>
          </div>
        )}

        <div className="card">
          <div className="card-header">
            <h3 className="card-title">РРЅС„РѕСЂРјР°С†РёСЏ</h3>
          </div>
          <p>Р’С‹ РІРѕС€Р»Рё РІ СЃРёСЃС‚РµРјСѓ РєР°Рє {user.role === 'manager' ? 'СЂСѓРєРѕРІРѕРґРёС‚РµР»СЊ' : 'РёСЃРїРѕР»РЅРёС‚РµР»СЊ'}.</p>
          {isManager ? (
            <p style={{ marginTop: '10px' }}>РЈ РІР°СЃ РµСЃС‚СЊ РґРѕСЃС‚СѓРї РєРѕ РІСЃРµРј РїСЂРѕРµРєС‚Р°Рј, Р·Р°РґР°С‡Р°Рј Рё РјРѕРЅС‚Р°Р¶Р°Рј. Р’С‹ РјРѕР¶РµС‚Рµ РїРѕРґС‚РІРµСЂР¶РґР°С‚СЊ РёР»Рё РѕС‚РєР»РѕРЅСЏС‚СЊ Р·Р°СЏРІРєРё РЅР° Р·Р°РєСѓРїРєСѓ РјР°С‚РµСЂРёР°Р»РѕРІ.</p>
          ) : (
            <p style={{ marginTop: '10px' }}>Р’С‹ РІРёРґРёС‚Рµ С‚РѕР»СЊРєРѕ Р·Р°РґР°С‡Рё Рё РјРѕРЅС‚Р°Р¶Рё, РЅР°Р·РЅР°С‡РµРЅРЅС‹Рµ РІР°Рј. Р’С‹ РјРѕР¶РµС‚Рµ СЃРѕР·РґР°РІР°С‚СЊ Р·Р°СЏРІРєРё РЅР° Р·Р°РєСѓРїРєСѓ РјР°С‚РµСЂРёР°Р»РѕРІ РґР»СЏ СЃРІРѕРёС… Р·Р°РґР°С‡.</p>
          )}
        </div>
      </main>
    </div>
  );
};

export default Dashboard;
