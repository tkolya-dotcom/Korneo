import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { projectsApi, tasksApi, installationsApi } from '../api';

const ProjectDetail = () => {
  const { id } = useParams();
  const { isManager } = useAuth();
  const [project, setProject] = useState(null);
  const [tasks, setTasks] = useState([]);
  const [installations, setInstallations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    loadData();
  }, [id]);

  const loadData = async () => {
    try {
      const [projectRes, tasksRes, installationsRes] = await Promise.all([
        projectsApi.getById(id),
        tasksApi.getAll({ project_id: id }),
        installationsApi.getAll({ project_id: id })
      ]);
      setProject(projectRes.project);
      setTasks(tasksRes.tasks || []);
      setInstallations(installationsRes.installations || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className="loading">Загрузка...</div>;
  }

  if (!project) {
    return <div className="container">Проект не найден</div>;
  }

  return (
    <div>
      <header className="header">
        <h1>{project.name}</h1>
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
            <h3 className="card-title">Информация о проекте</h3>
            <Link to="/projects" className="btn btn-secondary">Назад к проектам</Link>
          </div>
          <p><strong>Название:</strong> {project.name}</p>
          <p><strong>Описание:</strong> {project.description || '-'}</p>
          <p><strong>Статус:</strong> {project.status === 'active' ? 'Активный' : 'Архив'}</p>
          <p><strong>Создан:</strong> {new Date(project.created_at).toLocaleDateString('ru-RU')}</p>
          {project.creator && <p><strong>Создатель:</strong> {project.creator.name}</p>}
        </div>

        <div className="grid grid-2">
          <div className="card">
            <div className="card-header">
              <h3 className="card-title">Задачи ({tasks.length})</h3>
            </div>
            {tasks.length === 0 ? (
              <p>Нет задач</p>
            ) : (
              <table className="table">
                <tbody>
                  {tasks.map(task => (
                    <tr key={task.id}>
                      <td>
                        <Link to={`/tasks/${task.id}`}>{task.title}</Link>
                      </td>
                      <td>
                        <span className={`status-badge status-${task.status}`}>
                          {task.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>

          <div className="card">
            <div className="card-header">
              <h3 className="card-title">Монтажи ({installations.length})</h3>
            </div>
            {installations.length === 0 ? (
              <p>Нет монтажей</p>
            ) : (
              <table className="table">
                <tbody>
                  {installations.map(inst => (
                    <tr key={inst.id}>
                      <td>
                        <Link to={`/installations/${inst.id}`}>{inst.title}</Link>
                      </td>
                      <td>
                        <span className={`status-badge status-${inst.status}`}>
                          {inst.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      </main>
    </div>
  );
};

export default ProjectDetail;
