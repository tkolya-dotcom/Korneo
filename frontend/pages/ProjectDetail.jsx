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
    return <div className="loading">Р—Р°РіСЂСѓР·РєР°...</div>;
  }

  if (!project) {
    return <div className="container">РџСЂРѕРµРєС‚ РЅРµ РЅР°Р№РґРµРЅ</div>;
  }

  return (
    <div>
      <header className="header">
        <h1>{project.name}</h1>
        <nav className="header-nav">
          <Link to="/">Р“Р»Р°РІРЅР°СЏ</Link>
          <Link to="/projects">РџСЂРѕРµРєС‚С‹</Link>
          <Link to="/tasks">Р—Р°РґР°С‡Рё</Link>
          <Link to="/installations">РњРѕРЅС‚Р°Р¶Рё</Link>
          <Link to="/purchase-requests">Р—Р°СЏРІРєРё</Link>
        </nav>
      </header>

      <main className="container">
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">РРЅС„РѕСЂРјР°С†РёСЏ Рѕ РїСЂРѕРµРєС‚Рµ</h3>
            <Link to="/projects" className="btn btn-secondary">РќР°Р·Р°Рґ Рє РїСЂРѕРµРєС‚Р°Рј</Link>
          </div>
          <p><strong>РќР°Р·РІР°РЅРёРµ:</strong> {project.name}</p>
          <p><strong>РћРїРёСЃР°РЅРёРµ:</strong> {project.description || '-'}</p>
          <p><strong>РЎС‚Р°С‚СѓСЃ:</strong> {project.status === 'active' ? 'РђРєС‚РёРІРЅС‹Р№' : 'РђСЂС…РёРІ'}</p>
          <p><strong>РЎРѕР·РґР°РЅ:</strong> {new Date(project.created_at).toLocaleDateString('ru-RU')}</p>
          {project.creator && <p><strong>РЎРѕР·РґР°С‚РµР»СЊ:</strong> {project.creator.name}</p>}
        </div>

        <div className="grid grid-2">
          <div className="card">
            <div className="card-header">
              <h3 className="card-title">Р—Р°РґР°С‡Рё ({tasks.length})</h3>
            </div>
            {tasks.length === 0 ? (
              <p>РќРµС‚ Р·Р°РґР°С‡</p>
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
              <h3 className="card-title">РњРѕРЅС‚Р°Р¶Рё ({installations.length})</h3>
            </div>
            {installations.length === 0 ? (
              <p>РќРµС‚ РјРѕРЅС‚Р°Р¶РµР№</p>
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
