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

  // Calculate task status breakdown
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

  // Calculate installation status breakdown
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

  // Calculate overall progress
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
      new: 'Новая',
      planned: 'Запланирована',
      in_progress: 'В работе',
      waiting_materials: 'Ожидает материалов',
      done: 'Выполнена',
      postponed: 'Отложена'
    };
    return labels[status] || status;
  };

  const getInstallationStatusLabel = (status) => {
    const labels = {
      new: 'Новый',
      planned: 'Запланирован',
      in_progress: 'В работе',
      waiting_materials: 'Ожидает материалов',
      done: 'Завершён',
      postponed: 'Отложен'
    };
    return labels[status] || status;
  };

  if (loading) {
    return <div className="loading">Загрузка...</div>;
  }

  return (
    <div>
      <header className="header">
        <h1>Система управления задачами</h1>
        <nav className="header-nav">
          <Link to="/">Главная</Link>
          <Link to="/messenger">Чаты</Link>
          <Link to="/projects">Проекты</Link>
          <Link to="/tasks">Задачи</Link>
          <Link to="/installations">Монтажи</Link>
          <Link to="/purchase-requests">Заявки</Link>
        </nav>
        <div className="header-user">
          <span>{user.name} ({user.role === 'manager' ? 'Руководитель' : 'Исполнитель'})</span>
          <button onClick={logout}>Выйти</button>
        </div>
      </header>

      <main className="container">
        <h2 style={{ marginBottom: '20px' }}>Добро пожаловать, {user.name}!</h2>

        <div className="stats-grid">
          <div className="stat-card">
            <h3>{stats.projects}</h3>
            <p>Проектов</p>
            <Link to="/projects" className="btn btn-primary" style={{ marginTop: '10px', display: 'inline-block' }}>
              Подробнее
            </Link>
          </div>

          <div className="stat-card">
            <h3>{stats.tasks}</h3>
            <p>Задач</p>
            <Link to="/tasks" className="btn btn-primary" style={{ marginTop: '10px', display: 'inline-block' }}>
              Подробнее
            </Link>
          </div>

          <div className="stat-card">
            <h3>{stats.installations}</h3>
            <p>Монтажей</p>
            <Link to="/installations" className="btn btn-primary" style={{ marginTop: '10px', display: 'inline-block' }}>
              Подробнее
            </Link>
          </div>

          <div className="stat-card">
            <h3>{stats.pendingRequests}</h3>
            <p>Ожидающих заявок</p>
            <Link to="/purchase-requests" className="btn btn-primary" style={{ marginTop: '10px', display: 'inline-block' }}>
              Подробнее
            </Link>
          </div>
</div>

        {/* User Status Card - Shows online/offline users with real-time updates */}
        <UserStatusCard />

        {/* Progress Bar Section */}
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Общее выполнение</h3>
          </div>
          <div className="progress-container">
            <div className="progress-bar">
              <div 
                className="progress-fill" 
                style={{ width: `${overallProgress}%` }}
              ></div>
            </div>
            <div className="progress-text">
              <span>{overallProgress}% выполнено</span>
              <span>
                {tasks.filter(t => t.status === 'done').length + installations.filter(i => i.status === 'done').length} из {tasks.length + installations.length} завершено
              </span>
            </div>
          </div>
        </div>

        {/* Installation Status Breakdown */}
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Статусы монтажей</h3>
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
              <h3 className="card-title">Быстрые действия</h3>
            </div>
            <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
              <Link to="/projects" className="btn btn-primary">Создать проект</Link>
              <Link to="/tasks" className="btn btn-primary">Создать задачу</Link>
              <Link to="/installations" className="btn btn-primary">Создать монтаж</Link>
            </div>
          </div>
        )}

        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Информация</h3>
          </div>
          <p>Вы вошли в систему как {user.role === 'manager' ? 'руководитель' : 'исполнитель'}.</p>
          {isManager ? (
            <p style={{ marginTop: '10px' }}>У вас есть доступ ко всем проектам, задачам и монтажам. Вы можете подтверждать или отклонять заявки на закупку материалов.</p>
          ) : (
            <p style={{ marginTop: '10px' }}>Вы видите только задачи и монтажи, назначенные вам. Вы можете создавать заявки на закупку материалов для своих задач.</p>
          )}
        </div>
      </main>
    </div>
  );
};

export default Dashboard;
