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
      in_order: 'Р’ Р·Р°РєР°Р·Рµ',
      ready_for_receipt: 'Р“РѕС‚РѕРІ Рє РїРѕР»СѓС‡РµРЅРёСЋ',
      received: 'РџРѕР»СѓС‡РµРЅРѕ',
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
        <h1>РђСЂС…РёРІ</h1>
        <nav className="header-nav">
          <Link to="/">Р“Р»Р°РІРЅР°СЏ</Link>
          <Link to="/projects">РџСЂРѕРµРєС‚С‹</Link>
          <Link to="/tasks">Р—Р°РґР°С‡Рё</Link>
          <Link to="/installations">РњРѕРЅС‚Р°Р¶Рё</Link>
          <Link to="/purchase-requests">Р—Р°СЏРІРєРё</Link>
          <Link to="/archive">РђСЂС…РёРІ</Link>
        </nav>
      </header>

      <main className="container">
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">РђСЂС…РёРІРЅС‹Рµ Р·Р°РїРёСЃРё</h3>
          </div>

          {error && <div className="error">{error}</div>}

          {/* Tabs */}
          <div style={{ display: 'flex', gap: '10px', marginBottom: '20px' }}>
            <button
              className={`btn ${activeTab === 'tasks' ? 'btn-primary' : 'btn-secondary'}`}
              onClick={() => setActiveTab('tasks')}
            >
              Р—Р°РґР°С‡Рё ({tasks.length})
            </button>
            <button
              className={`btn ${activeTab === 'installations' ? 'btn-primary' : 'btn-secondary'}`}
              onClick={() => setActiveTab('installations')}
            >
              РњРѕРЅС‚Р°Р¶Рё ({installations.length})
            </button>
          </div>

          {/* Tasks Tab */}
          {activeTab === 'tasks' && (
            <>
              {tasks.length === 0 ? (
                <div className="empty-state">
                  <h3>РќРµС‚ Р°СЂС…РёРІРЅС‹С… Р·Р°РґР°С‡</h3>
                </div>
              ) : (
                <table className="table">
                  <thead>
                    <tr>
                      <th>РќР°Р·РІР°РЅРёРµ</th>
                      <th>РџСЂРѕРµРєС‚</th>
                      <th>РСЃРїРѕР»РЅРёС‚РµР»СЊ</th>
                      <th>РЎС‚Р°С‚СѓСЃ</th>
                      <th>РЎСЂРѕРє</th>
                      <th>Р”РµР№СЃС‚РІРёСЏ</th>
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
                            Р’РѕСЃСЃС‚Р°РЅРѕРІРёС‚СЊ
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
                  <h3>РќРµС‚ Р°СЂС…РёРІРЅС‹С… РјРѕРЅС‚Р°Р¶РµР№</h3>
                </div>
              ) : (
                <table className="table">
                  <thead>
                    <tr>
                      <th>РќР°Р·РІР°РЅРёРµ</th>
                      <th>РџСЂРѕРµРєС‚</th>
                      <th>РСЃРїРѕР»РЅРёС‚РµР»СЊ</th>
                      <th>РЎС‚Р°С‚СѓСЃ</th>
                      <th>Р”Р°С‚Р°</th>
                      <th>РђРґСЂРµСЃ</th>
                      <th>Р”РµР№СЃС‚РІРёСЏ</th>
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
                            Р’РѕСЃСЃС‚Р°РЅРѕРІРёС‚СЊ
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

