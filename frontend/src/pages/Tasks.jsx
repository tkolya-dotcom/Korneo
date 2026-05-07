import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { tasksApi, projectsApi, authApi } from '../api';

const Tasks = () => {
  const { isManager } = useAuth();
  const [tasks, setTasks] = useState([]);
  const [projects, setProjects] = useState([]);
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [editingTask, setEditingTask] = useState(null);
  const [deletingTask, setDeletingTask] = useState(null);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [formData, setFormData] = useState({
    project_id: '',
    title: '',
    description: '',
    assignee_id: '',
    status: 'new',
    due_date: ''
  });
  const [error, setError] = useState('');

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [tasksRes, projectsRes, usersRes] = await Promise.all([
        tasksApi.getAll(),
        projectsApi.getAll(),
        authApi.getUsers('worker')
      ]);
      setTasks(tasksRes.tasks || []);
      setProjects(projectsRes.projects || []);
      setUsers(usersRes.users || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    e.stopPropagation();
    setError('');
    
    if (!formData.project_id || !formData.title) {
      setError('РџРѕР¶Р°Р»СѓР№СЃС‚Р°, Р·Р°РїРѕР»РЅРёС‚Рµ РѕР±СЏР·Р°С‚РµР»СЊРЅС‹Рµ РїРѕР»СЏ (РїСЂРѕРµРєС‚ Рё РЅР°Р·РІР°РЅРёРµ)');
      return;
    }
    
    try {
      if (editingTask) {
        await tasksApi.update(editingTask.id, formData);
        setShowModal(false);
        setEditingTask(null);
      } else {
        console.log('Creating task with data:', formData);
        const result = await tasksApi.create(formData);
        console.log('Creation result:', result);
        setShowModal(false);
        setShowCreateModal(false);
      }
      setFormData({ project_id: '', title: '', description: '', assignee_id: '', status: 'new', due_date: '' });
      loadData();
    } catch (err) {
      console.error('Error creating task:', err);
      setError(err.message || 'РћС€РёР±РєР° РїСЂРё СЃРѕР·РґР°РЅРёРё Р·Р°РґР°С‡Рё. РџСЂРѕРІРµСЂСЊС‚Рµ РєРѕРЅСЃРѕР»СЊ Р±СЂР°СѓР·РµСЂР° РґР»СЏ РґРµС‚Р°Р»РµР№.');
    }
  };

  const handleEdit = (task) => {
    setEditingTask(task);
    setFormData({
      project_id: task.project_id || '',
      title: task.title || '',
      description: task.description || '',
      assignee_id: task.assignee_id || '',
      status: task.status || 'new',
      due_date: task.due_date ? task.due_date.split('T')[0] : ''
    });
    setShowModal(true);
  };

  const handleDelete = async () => {
    try {
      await tasksApi.delete(deletingTask.id);
      setShowDeleteModal(false);
      setDeletingTask(null);
      loadData();
    } catch (err) {
      setError(err.message);
    }
  };

  const openCreateModal = () => {
    setEditingTask(null);
    setFormData({ project_id: '', title: '', description: '', assignee_id: '', status: 'new', due_date: '' });
    setShowModal(true);
    setShowCreateModal(true);
  };

  const handleStatusChange = async (taskId, newStatus) => {
    try {
      await tasksApi.update(taskId, { status: newStatus });
      loadData();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleArchiveTask = async (taskId) => {
    try {
      await tasksApi.update(taskId, { is_archived: true });
      loadData();
    } catch (err) {
      setError(err.message);
    }
  };

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

  if (loading) {
    return <div className="loading">Р—Р°РіСЂСѓР·РєР°...</div>;
  }

  return (
    <div>
      <header className="header">
        <h1>Р—Р°РґР°С‡Рё</h1>
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
            <h3 className="card-title">РЎРїРёСЃРѕРє Р·Р°РґР°С‡</h3>
            {isManager && (
              <button className="btn btn-primary" onClick={openCreateModal}>
                РЎРѕР·РґР°С‚СЊ Р·Р°РґР°С‡Сѓ
              </button>
            )}
          </div>

          {error && <div className="error">{error}</div>}

          {tasks.length === 0 ? (
            <div className="empty-state">
              <h3>РќРµС‚ Р·Р°РґР°С‡</h3>
              <p>РЎРѕР·РґР°Р№С‚Рµ РїРµСЂРІСѓСЋ Р·Р°РґР°С‡Сѓ</p>
            </div>
          ) : (
            <table className="table">
              <thead>
                <tr>
                  <th>РќР°Р·РІР°РЅРёРµ</th>
                  <th>РћРїРёСЃР°РЅРёРµ</th>
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
                    <td>{task.description ? (task.description.length > 50 ? task.description.substring(0, 50) + '...' : task.description) : '-'}</td>
                    <td>{task.project?.name || '-'}</td>
                    <td>{task.assignee?.name || '-'}</td>
                    <td>
                      <select
                        className={`status-badge status-${task.status}`}
                        value={task.status}
                        onChange={(e) => handleStatusChange(task.id, e.target.value)}
                        style={{ border: 'none', cursor: 'pointer' }}
                      >
                        <option value="new">РќРѕРІР°СЏ</option>
                        <option value="planned">Р—Р°РїР»Р°РЅРёСЂРѕРІР°РЅР°</option>
                        <option value="in_progress">Р’ СЂР°Р±РѕС‚Рµ</option>
                        <option value="waiting_materials">РћР¶РёРґР°РµС‚ РјР°С‚РµСЂРёР°Р»РѕРІ</option>
                        <option value="done">Р’С‹РїРѕР»РЅРµРЅР°</option>
                        <option value="postponed">РћС‚Р»РѕР¶РµРЅР°</option>
                      </select>
                    </td>
                    <td>{task.due_date ? new Date(task.due_date).toLocaleDateString('ru-RU') : '-'}</td>
                    <td>
                      <div style={{ display: 'flex', gap: '5px' }}>
                        <Link to={`/tasks/${task.id}`} className="btn btn-secondary">
                          РџРѕРґСЂРѕР±РЅРµРµ
                        </Link>
                        {isManager && (
                          <>
                            <button 
                              className="btn btn-primary" 
                              onClick={() => handleEdit(task)}
                              style={{ padding: '5px 10px', fontSize: '12px' }}
                            >
                              РР·РјРµРЅРёС‚СЊ
                            </button>
                            <button 
                              className="btn btn-secondary" 
                              onClick={() => handleArchiveTask(task.id)}
                              style={{ padding: '5px 10px', fontSize: '12px' }}
                              title="РџРµСЂРµРјРµСЃС‚РёС‚СЊ РІ Р°СЂС…РёРІ"
                            >
                              Р’ Р°СЂС…РёРІ
                            </button>
                            <button 
                              className="btn btn-danger" 
                              onClick={() => {
                                setDeletingTask(task);
                                setShowDeleteModal(true);
                              }}
                              style={{ padding: '5px 10px', fontSize: '12px' }}
                            >
                              РЈРґР°Р»РёС‚СЊ
                            </button>
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </main>

      {showModal && (
        <div className="modal-overlay" onClick={() => { setShowModal(false); setShowCreateModal(false); }}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2>{editingTask ? 'Р РµРґР°РєС‚РёСЂРѕРІР°С‚СЊ Р·Р°РґР°С‡Сѓ' : 'РЎРѕР·РґР°С‚СЊ Р·Р°РґР°С‡Сѓ'}</h2>
              <button className="modal-close" onClick={() => { setShowModal(false); setShowCreateModal(false); }}>&times;</button>
            </div>
            <form onSubmit={handleSubmit}>
              {error && <div className="error">{error}</div>}
              <div className="form-group">
                <label>РџСЂРѕРµРєС‚ *</label>
                <select
                  value={formData.project_id}
                  onChange={e => setFormData({ ...formData, project_id: e.target.value })}
                  required
                >
                  <option value="">Р’С‹Р±РµСЂРёС‚Рµ РїСЂРѕРµРєС‚</option>
                  {projects.map(p => (
                    <option key={p.id} value={p.id}>{p.name}</option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label>РќР°Р·РІР°РЅРёРµ *</label>
                <input
                  type="text"
                  value={formData.title}
                  onChange={e => setFormData({ ...formData, title: e.target.value })}
                  required
                />
              </div>
              <div className="form-group">
                <label>РћРїРёСЃР°РЅРёРµ</label>
                <textarea
                  value={formData.description}
                  onChange={e => setFormData({ ...formData, description: e.target.value })}
                />
              </div>
              <div className="form-group">
                <label>РСЃРїРѕР»РЅРёС‚РµР»СЊ</label>
                <select
                  value={formData.assignee_id}
                  onChange={e => setFormData({ ...formData, assignee_id: e.target.value })}
                >
                  <option value="">Р’С‹Р±РµСЂРёС‚Рµ РёСЃРїРѕР»РЅРёС‚РµР»СЏ</option>
                  {users.map(u => (
                    <option key={u.id} value={u.id}>{u.name}</option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label>РЎСЂРѕРє</label>
                <input
                  type="date"
                  value={formData.due_date}
                  onChange={e => setFormData({ ...formData, due_date: e.target.value })}
                />
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => { setShowModal(false); setShowCreateModal(false); }}>
                  РћС‚РјРµРЅР°
                </button>
                <button type="submit" className="btn btn-primary">
                  {editingTask ? 'РЎРѕС…СЂР°РЅРёС‚СЊ' : 'РЎРѕР·РґР°С‚СЊ'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {showDeleteModal && (
        <div className="modal-overlay" onClick={() => setShowDeleteModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2>РџРѕРґС‚РІРµСЂР¶РґРµРЅРёРµ СѓРґР°Р»РµРЅРёСЏ</h2>
              <button className="modal-close" onClick={() => setShowDeleteModal(false)}>&times;</button>
            </div>
            <div style={{ padding: '20px' }}>
              <p>Р’С‹ СѓРІРµСЂРµРЅС‹, С‡С‚Рѕ С…РѕС‚РёС‚Рµ СѓРґР°Р»РёС‚СЊ Р·Р°РґР°С‡Сѓ "{deletingTask?.title}"?</p>
              <p style={{ color: '#d32f2f', fontSize: '14px' }}>Р­С‚Рѕ РґРµР№СЃС‚РІРёРµ РЅРµР»СЊР·СЏ РѕС‚РјРµРЅРёС‚СЊ.</p>
            </div>
            <div className="modal-footer">
              <button type="button" className="btn btn-secondary" onClick={() => setShowDeleteModal(false)}>
                РћС‚РјРµРЅР°
              </button>
              <button type="button" className="btn btn-danger" onClick={handleDelete}>
                РЈРґР°Р»РёС‚СЊ
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Tasks;
