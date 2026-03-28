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
      setError('Пожалуйста, заполните обязательные поля (проект и название)');
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
      setError(err.message || 'Ошибка при создании задачи. Проверьте консоль браузера для деталей.');
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
      new: 'Новая',
      planned: 'Запланирована',
      in_progress: 'В работе',
      waiting_materials: 'Ожидает материалов',
      done: 'Выполнена',
      postponed: 'Отложена'
    };
    return labels[status] || status;
  };

  if (loading) {
    return <div className="loading">Загрузка...</div>;
  }

  return (
    <div>
      <header className="header">
        <h1>Задачи</h1>
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
            <h3 className="card-title">Список задач</h3>
            {isManager && (
              <button className="btn btn-primary" onClick={openCreateModal}>
                Создать задачу
              </button>
            )}
          </div>

          {error && <div className="error">{error}</div>}

          {tasks.length === 0 ? (
            <div className="empty-state">
              <h3>Нет задач</h3>
              <p>Создайте первую задачу</p>
            </div>
          ) : (
            <table className="table">
              <thead>
                <tr>
                  <th>Название</th>
                  <th>Описание</th>
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
                        <option value="new">Новая</option>
                        <option value="planned">Запланирована</option>
                        <option value="in_progress">В работе</option>
                        <option value="waiting_materials">Ожидает материалов</option>
                        <option value="done">Выполнена</option>
                        <option value="postponed">Отложена</option>
                      </select>
                    </td>
                    <td>{task.due_date ? new Date(task.due_date).toLocaleDateString('ru-RU') : '-'}</td>
                    <td>
                      <div style={{ display: 'flex', gap: '5px' }}>
                        <Link to={`/tasks/${task.id}`} className="btn btn-secondary">
                          Подробнее
                        </Link>
                        {isManager && (
                          <>
                            <button 
                              className="btn btn-primary" 
                              onClick={() => handleEdit(task)}
                              style={{ padding: '5px 10px', fontSize: '12px' }}
                            >
                              Изменить
                            </button>
                            <button 
                              className="btn btn-secondary" 
                              onClick={() => handleArchiveTask(task.id)}
                              style={{ padding: '5px 10px', fontSize: '12px' }}
                              title="Переместить в архив"
                            >
                              В архив
                            </button>
                            <button 
                              className="btn btn-danger" 
                              onClick={() => {
                                setDeletingTask(task);
                                setShowDeleteModal(true);
                              }}
                              style={{ padding: '5px 10px', fontSize: '12px' }}
                            >
                              Удалить
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
              <h2>{editingTask ? 'Редактировать задачу' : 'Создать задачу'}</h2>
              <button className="modal-close" onClick={() => { setShowModal(false); setShowCreateModal(false); }}>&times;</button>
            </div>
            <form onSubmit={handleSubmit}>
              {error && <div className="error">{error}</div>}
              <div className="form-group">
                <label>Проект *</label>
                <select
                  value={formData.project_id}
                  onChange={e => setFormData({ ...formData, project_id: e.target.value })}
                  required
                >
                  <option value="">Выберите проект</option>
                  {projects.map(p => (
                    <option key={p.id} value={p.id}>{p.name}</option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label>Название *</label>
                <input
                  type="text"
                  value={formData.title}
                  onChange={e => setFormData({ ...formData, title: e.target.value })}
                  required
                />
              </div>
              <div className="form-group">
                <label>Описание</label>
                <textarea
                  value={formData.description}
                  onChange={e => setFormData({ ...formData, description: e.target.value })}
                />
              </div>
              <div className="form-group">
                <label>Исполнитель</label>
                <select
                  value={formData.assignee_id}
                  onChange={e => setFormData({ ...formData, assignee_id: e.target.value })}
                >
                  <option value="">Выберите исполнителя</option>
                  {users.map(u => (
                    <option key={u.id} value={u.id}>{u.name}</option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label>Срок</label>
                <input
                  type="date"
                  value={formData.due_date}
                  onChange={e => setFormData({ ...formData, due_date: e.target.value })}
                />
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => { setShowModal(false); setShowCreateModal(false); }}>
                  Отмена
                </button>
                <button type="submit" className="btn btn-primary">
                  {editingTask ? 'Сохранить' : 'Создать'}
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
              <h2>Подтверждение удаления</h2>
              <button className="modal-close" onClick={() => setShowDeleteModal(false)}>&times;</button>
            </div>
            <div style={{ padding: '20px' }}>
              <p>Вы уверены, что хотите удалить задачу "{deletingTask?.title}"?</p>
              <p style={{ color: '#d32f2f', fontSize: '14px' }}>Это действие нельзя отменить.</p>
            </div>
            <div className="modal-footer">
              <button type="button" className="btn btn-secondary" onClick={() => setShowDeleteModal(false)}>
                Отмена
              </button>
              <button type="button" className="btn btn-danger" onClick={handleDelete}>
                Удалить
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Tasks;
