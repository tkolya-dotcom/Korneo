import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { projectsApi } from '../api';

const Projects = () => {
  const { isManager } = useAuth();
  const [projects, setProjects] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [editingProject, setEditingProject] = useState(null);
  const [deletingProject, setDeletingProject] = useState(null);
  const [formData, setFormData] = useState({ name: '', description: '' });
  const [error, setError] = useState('');

  useEffect(() => {
    loadProjects();
  }, []);

  const loadProjects = async () => {
    try {
      const data = await projectsApi.getAll();
      setProjects(data.projects || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    try {
      if (editingProject) {
        await projectsApi.update(editingProject.id, formData);
        setShowModal(false);
        setEditingProject(null);
      } else {
        await projectsApi.create(formData);
        setShowModal(false);
      }
      setFormData({ name: '', description: '' });
      loadProjects();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleEdit = (project) => {
    setEditingProject(project);
    setFormData({ name: project.name, description: project.description || '' });
    setShowModal(true);
  };

  const handleDelete = async () => {
    try {
      await projectsApi.delete(deletingProject.id);
      setShowDeleteModal(false);
      setDeletingProject(null);
      loadProjects();
    } catch (err) {
      setError(err.message);
    }
  };

  const openCreateModal = () => {
    setEditingProject(null);
    setFormData({ name: '', description: '' });
    setShowModal(true);
  };

  if (loading) {
    return <div className="loading">Загрузка...</div>;
  }

  return (
    <div>
      <header className="header">
        <h1>Проекты</h1>
        <nav className="header-nav">
          <Link to="/">Главная</Link>
          <Link to="/projects">Проекты</Link>
          <Link to="/tasks">Задачи</Link>
          <Link to="/installations">Монтажи</Link>
          <Link to="/purchase-requests">Заявки</Link>
        </nav>
      </header>

      <main className="container">
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Список проектов</h3>
            {isManager && (
              <button className="btn btn-primary" onClick={() => setShowModal(true)}>
                Создать проект
              </button>
            )}
          </div>

          {error && <div className="error">{error}</div>}

          {projects.length === 0 ? (
            <div className="empty-state">
              <h3>Нет проектов</h3>
              <p>Создайте первый проект</p>
            </div>
          ) : (
            <table className="table">
              <thead>
                <tr>
                  <th>Название</th>
                  <th>Описание</th>
                  <th>Статус</th>
                  <th>Дата создания</th>
                  <th>Действия</th>
                </tr>
              </thead>
              <tbody>
                {projects.map(project => (
                  <tr key={project.id}>
                    <td>{project.name}</td>
                    <td>{project.description || '-'}</td>
                    <td>
                      <span className={`status-badge status-${project.status}`}>
                        {project.status === 'active' ? 'Активный' : 'Архив'}
                      </span>
                    </td>
                    <td>{new Date(project.created_at).toLocaleDateString('ru-RU')}</td>
                    <td>
                      <div style={{ display: 'flex', gap: '5px' }}>
                        <Link to={`/projects/${project.id}`} className="btn btn-secondary">
                          Подробнее
                        </Link>
                        {isManager && (
                          <>
                            <button 
                              className="btn btn-primary" 
                              onClick={() => handleEdit(project)}
                              style={{ padding: '5px 10px', fontSize: '12px' }}
                            >
                              Изменить
                            </button>
                            <button 
                              className="btn btn-danger" 
                              onClick={() => {
                                setDeletingProject(project);
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
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2>{editingProject ? 'Редактировать проект' : 'Создать проект'}</h2>
              <button className="modal-close" onClick={() => setShowModal(false)}>&times;</button>
            </div>
            <form onSubmit={handleSubmit}>
              {error && <div className="error">{error}</div>}
              <div className="form-group">
                <label>Название *</label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={e => setFormData({ ...formData, name: e.target.value })}
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
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setShowModal(false)}>
                  Отмена
                </button>
                <button type="submit" className="btn btn-primary">
                  {editingProject ? 'Сохранить' : 'Создать'}
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
              <p>Вы уверены, что хотите удалить проект "{deletingProject?.name}"?</p>
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

export default Projects;
