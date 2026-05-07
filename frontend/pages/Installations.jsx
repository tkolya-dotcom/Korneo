import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { installationsApi, projectsApi, authApi } from '../api';

const Installations = () => {
  const { isManager } = useAuth();
  const [installations, setInstallations] = useState([]);
  const [projects, setProjects] = useState([]);
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [editingInstallation, setEditingInstallation] = useState(null);
  const [deletingInstallation, setDeletingInstallation] = useState(null);
  const [formData, setFormData] = useState({
    project_id: '',
    title: '',
    description: '',
    assignee_id: '',
    status: 'new',
    scheduled_at: '',
    address: '',
    receipt_address: '',
    received_at: ''
  });
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [installationsRes, projectsRes, usersRes] = await Promise.all([
        installationsApi.getAll(),
        projectsApi.getAll(),
        authApi.getUsers('worker')
      ]);
      setInstallations(installationsRes.installations || []);
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
    setSubmitting(true);
    
    if (!formData.project_id || !formData.title) {
      setError('РџРѕР¶Р°Р»СѓР№СЃС‚Р°, Р·Р°РїРѕР»РЅРёС‚Рµ РѕР±СЏР·Р°С‚РµР»СЊРЅС‹Рµ РїРѕР»СЏ (РїСЂРѕРµРєС‚ Рё РЅР°Р·РІР°РЅРёРµ)');
      setSubmitting(false);
      return;
    }
    
    try {
      if (editingInstallation) {
        await installationsApi.update(editingInstallation.id, formData);
        setShowModal(false);
        setEditingInstallation(null);
      } else {
        console.log('Creating installation with data:', formData);
        const result = await installationsApi.create(formData);
        console.log('Creation result:', result);
        setShowModal(false);
      }
      setFormData({
        project_id: '',
        title: '',
        description: '',
        assignee_id: '',
        status: 'new',
        scheduled_at: '',
        address: '',
        receipt_address: '',
        received_at: ''
      });
      loadData();
    } catch (err) {
      console.error('Error creating installation:', err);
      setError(err.message || 'РћС€РёР±РєР° РїСЂРё СЃРѕР·РґР°РЅРёРё РјРѕРЅС‚Р°Р¶Р°. РџСЂРѕРІРµСЂСЊС‚Рµ РєРѕРЅСЃРѕР»СЊ Р±СЂР°СѓР·РµСЂР° РґР»СЏ РґРµС‚Р°Р»РµР№.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleEdit = (installation) => {
    setEditingInstallation(installation);
    setFormData({
      project_id: installation.project_id || '',
      title: installation.title || '',
      description: installation.description || '',
      assignee_id: installation.assignee_id || '',
      status: installation.status || 'new',
      scheduled_at: installation.scheduled_at ? installation.scheduled_at.slice(0, 16) : '',
      address: installation.address || '',
      receipt_address: installation.receipt_address || '',
      received_at: installation.received_at ? installation.received_at.slice(0, 16) : ''
    });
    setShowModal(true);
  };

  const handleDelete = async () => {
    try {
      await installationsApi.delete(deletingInstallation.id);
      setShowDeleteModal(false);
      setDeletingInstallation(null);
      loadData();
    } catch (err) {
      setError(err.message);
    }
  };

  const openCreateModal = () => {
    setEditingInstallation(null);
    setFormData({
      project_id: '',
      title: '',
      description: '',
      assignee_id: '',
      status: 'new',
      scheduled_at: '',
      address: '',
      receipt_address: '',
      received_at: ''
    });
    setShowModal(true);
  };

  const handleStatusChange = async (installationId, newStatus) => {
    try {
      await installationsApi.update(installationId, { status: newStatus });
      loadData();
    } catch (err) {
      setError(err.message);
    }
  };

  const getStatusLabel = (status) => {
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
        <h1>РњРѕРЅС‚Р°Р¶Рё</h1>
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
            <h3 className="card-title">РЎРїРёСЃРѕРє РјРѕРЅС‚Р°Р¶РµР№</h3>
            {isManager && (
              <button className="btn btn-primary" onClick={openCreateModal}>
                РЎРѕР·РґР°С‚СЊ РјРѕРЅС‚Р°Р¶
              </button>
            )}
          </div>

          {error && <div className="error">{error}</div>}

          {installations.length === 0 ? (
            <div className="empty-state">
              <h3>РќРµС‚ РјРѕРЅС‚Р°Р¶РµР№</h3>
              <p>РЎРѕР·РґР°Р№С‚Рµ РїРµСЂРІС‹Р№ РјРѕРЅС‚Р°Р¶</p>
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
                  <th>Р”Р°С‚Р°</th>
                  <th>РђРґСЂРµСЃ</th>
                  <th>Р”РµР№СЃС‚РІРёСЏ</th>
                </tr>
              </thead>
              <tbody>
                {installations.map(inst => (
                  <tr key={inst.id}>
                    <td>{inst.title}</td>
                    <td>{inst.description ? (inst.description.length > 50 ? inst.description.substring(0, 50) + '...' : inst.description) : '-'}</td>
                    <td>{inst.project?.name || '-'}</td>
                    <td>{inst.assignee?.name || '-'}</td>
                    <td>
                      <select
                        className={`status-badge status-${inst.status}`}
                        value={inst.status}
                        onChange={(e) => handleStatusChange(inst.id, e.target.value)}
                        style={{ border: 'none', cursor: 'pointer' }}
                      >
                        <option value="new">РќРѕРІС‹Р№</option>
                        <option value="planned">Р—Р°РїР»Р°РЅРёСЂРѕРІР°РЅ</option>
                        <option value="in_progress">Р’ СЂР°Р±РѕС‚Рµ</option>
                        <option value="waiting_materials">РћР¶РёРґР°РµС‚ РјР°С‚РµСЂРёР°Р»РѕРІ</option>
                        <option value="in_order">Р’ Р·Р°РєР°Р·Рµ</option>
                        <option value="ready_for_receipt">Р“РѕС‚РѕРІ Рє РїРѕР»СѓС‡РµРЅРёСЋ</option>
                        <option value="received">РџРѕР»СѓС‡РµРЅРѕ</option>
                        <option value="done">Р—Р°РІРµСЂС€С‘РЅ</option>
                        <option value="postponed">РћС‚Р»РѕР¶РµРЅ</option>
                      </select>
                    </td>
                    <td>{inst.scheduled_at ? new Date(inst.scheduled_at).toLocaleDateString('ru-RU') : '-'}</td>
                    <td>{inst.address || '-'}</td>
                    <td>
                      <div style={{ display: 'flex', gap: '5px' }}>
                        <Link to={`/installations/${inst.id}`} className="btn btn-secondary">
                          РџРѕРґСЂРѕР±РЅРµРµ
                        </Link>
                        {isManager && (
                          <>
                            <button 
                              className="btn btn-primary" 
                              onClick={() => handleEdit(inst)}
                              style={{ padding: '5px 10px', fontSize: '12px' }}
                            >
                              РР·РјРµРЅРёС‚СЊ
                            </button>
                            <button 
                              className="btn btn-danger" 
                              onClick={() => {
                                setDeletingInstallation(inst);
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
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2>{editingInstallation ? 'Р РµРґР°РєС‚РёСЂРѕРІР°С‚СЊ РјРѕРЅС‚Р°Р¶' : 'РЎРѕР·РґР°С‚СЊ РјРѕРЅС‚Р°Р¶'}</h2>
              <button className="modal-close" onClick={() => setShowModal(false)}>&times;</button>
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
                <label>Р”Р°С‚Р° РјРѕРЅС‚Р°Р¶Р°</label>
                <input
                  type="datetime-local"
                  value={formData.scheduled_at}
                  onChange={e => setFormData({ ...formData, scheduled_at: e.target.value })}
                />
              </div>
              <div className="form-group">
                <label>РђРґСЂРµСЃ</label>
                <input
                  type="text"
                  value={formData.address}
                  onChange={e => setFormData({ ...formData, address: e.target.value })}
                />
              </div>
              {(formData.status === 'ready_for_receipt' || formData.status === 'received') && (
                <>
                  <div className="form-group">
                    <label>РђРґСЂРµСЃ РїРѕР»СѓС‡РµРЅРёСЏ</label>
                    <input
                      type="text"
                      value={formData.receipt_address}
                      onChange={e => setFormData({ ...formData, receipt_address: e.target.value })}
                      placeholder="Р’РІРµРґРёС‚Рµ Р°РґСЂРµСЃ РїРѕР»СѓС‡РµРЅРёСЏ"
                    />
                  </div>
                  {formData.status === 'received' && (
                    <div className="form-group">
                      <label>Р”Р°С‚Р° РїРѕР»СѓС‡РµРЅРёСЏ</label>
                      <input
                        type="datetime-local"
                        value={formData.received_at}
                        onChange={e => setFormData({ ...formData, received_at: e.target.value })}
                      />
                    </div>
                  )}
                </>
              )}
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setShowModal(false)} disabled={submitting}>
                  РћС‚РјРµРЅР°
                </button>
                <button type="submit" className="btn btn-primary" disabled={submitting}>
                  {submitting ? 'РЎРѕС…СЂР°РЅРµРЅРёРµ...' : (editingInstallation ? 'РЎРѕС…СЂР°РЅРёС‚СЊ' : 'РЎРѕР·РґР°С‚СЊ')}
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
              <p>Р’С‹ СѓРІРµСЂРµРЅС‹, С‡С‚Рѕ С…РѕС‚РёС‚Рµ СѓРґР°Р»РёС‚СЊ РјРѕРЅС‚Р°Р¶ "{deletingInstallation?.title}"?</p>
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

export default Installations;
