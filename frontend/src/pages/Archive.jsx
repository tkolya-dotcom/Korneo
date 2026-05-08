import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { tasksApi, installationsApi } from '../api';

const Archive = () => {
  const { isManager } = useAuth();
  const [tasks, setTasks] = useState([]);
  const [installations, setInstallations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('tasks');
  const [error, setError] = useState('');

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      const [tasksRes, installationsRes] = await Promise.all([
        tasksApi.getArchived(),
        installationsApi.getArchived()
      ]);
      setTasks(tasksRes.tasks || []);
      setInstallations(installationsRes.installations || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleUnarchiveTask = async (taskId) => {
    try {
      await tasksApi.update(taskId, { is_archived: false });
      loadData();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleUnarchiveInstallation = async (installationId) => {
    try {
      await installationsApi.update(installationId, { is_archived: false });
      loadData();
    } catch (err) {
      setError(err.message);
    }
  };

  const getTaskStatusLabel = (status) => {
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
      in_order: 'В заказе',
      ready_for_receipt: 'Готов к получению',
      received: 'Получено',
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
        <h1>Архив</h1>
        <nav className="header-nav">
          <Link to="/">Главная</Link>
          <Link to="/projects">Проекты</Link>
          <Link to="/tasks">Задачи</Link>
          <Link to="/installations">Монтажи</Link>
          <Link to="/purchase-requests">Заявки</Link>
          <Link to="/archive">Архив</Link>
        </nav>
      </header>

      <main className="container">
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Архивные записи</h3>
          </div>

          {error && <div className="error">{error}</div>}

          {/* Tabs */}
          <div style={{ display: 'flex', gap: '10px', marginBottom: '20px' }}>
            <button
              className={`btn ${activeTab === 'tasks' ? 'btn-primary' : 'btn-secondary'}`}
              onClick={() => setActiveTab('tasks')}
            >
              Задачи ({tasks.length})
            </button>
            <button
              className={`btn ${activeTab === 'installations' ? 'btn-primary' : 'btn-secondary'}`}
              onClick={() => setActiveTab('installations')}
            >
              Монтажи ({installations.length})
            </button>
          </div>

          {/* Tasks Tab */}
          {activeTab === 'tasks' && (
            <>
              {tasks.length === 0 ? (
                <div className="empty-state">
                  <h3>Нет архивных задач</h3>
                </div>
              ) : (
                <table className="table">
                  <thead>
                    <tr>
                      <th>Название</th>
                      <th>Проект</th>
                      <th>Исполнитель</th>
                      <th>Статус</th>
                      <th>Срок</th>
                      <th>Действия</th>
                    </tr>
                  </thead>
                  <tbody>
                    {tasks.map(task => (
                      <tr key={task.id}>
                        <td>{task.title}</td>
                        <td>{task.project?.name || '-'}</td>
                        <td>{task.assignee?.name || '-'}</td>
                        <td>
                          <span className={`status-badge status-${task.status}`}>
                            {getTaskStatusLabel(task.status)}
                          </span>
                        </td>
                        <td>{task.due_date ? new Date(task.due_date).toLocaleDateString('ru-RU') : '-'}</td>
                        <td>
                          <button
                            className="btn btn-secondary"
                            onClick={() => handleUnarchiveTask(task.id)}
                            style={{ padding: '5px 10px', fontSize: '12px' }}
                          >
                            Восстановить
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </>
          )}

          {/* Installations Tab */}
          {activeTab === 'installations' && (
            <>
              {installations.length === 0 ? (
                <div className="empty-state">
                  <h3>Нет архивных монтажей</h3>
                </div>
              ) : (
                <table className="table">
                  <thead>
                    <tr>
                      <th>Название</th>
                      <th>Проект</th>
                      <th>Исполнитель</th>
                      <th>Статус</th>
                      <th>Дата</th>
                      <th>Адрес</th>
                      <th>Действия</th>
                    </tr>
                  </thead>
                  <tbody>
                    {installations.map(inst => (
                      <tr key={inst.id}>
                        <td>{inst.title}</td>
                        <td>{inst.project?.name || '-'}</td>
                        <td>{inst.assignee?.name || '-'}</td>
                        <td>
                          <span className={`status-badge status-${inst.status}`}>
                            {getInstallationStatusLabel(inst.status)}
                          </span>
                        </td>
                        <td>{inst.scheduled_at ? new Date(inst.scheduled_at).toLocaleDateString('ru-RU') : '-'}</td>
                        <td>{inst.address || '-'}</td>
                        <td>
                          <button
                            className="btn btn-secondary"
                            onClick={() => handleUnarchiveInstallation(inst.id)}
                            style={{ padding: '5px 10px', fontSize: '12px' }}
                          >
                            Восстановить
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </>
          )}
        </div>
      </main>
    </div>
  );
};

export default Archive;

