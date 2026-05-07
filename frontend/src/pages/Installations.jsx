import React, { useState, useEffect, useRef } from 'react';
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
  const [showStatusModal, setShowStatusModal] = useState(false);
  const [statusChangeData, setStatusChangeData] = useState({
    installationId: null,
    newStatus: '',
    receipt_address: '',
    received_at: ''
  });
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
    received_at: '',
    id_ploshadki: '',
    servisnyy_id: '',
    rayon: '',
    planovaya_data_1_kv_2026: '',
    id_sk1: '',
    naimenovanie_sk1: '',
    status_oborudovaniya1: '',
    tip_sk_po_dogovoru1: '',
    id_sk2: '',
    naimenovanie_sk2: '',
    status_oborudovaniya2: '',
    tip_sk_po_dogovoru2: '',
    id_sk3: '',
    naimenovanie_sk3: '',
    status_oborudovaniya3: '',
    tip_sk_po_dogovoru3: '',
    id_sk4: '',
    naimenovanie_sk4: '',
    status_oborudovaniya4: '',
    tip_sk_po_dogovoru4: '',
    id_sk5: '',
    naimenovanie_sk5: '',
    status_oborudovaniya5: '',
    tip_sk_po_dogovoru5: '',
    id_sk6: '',
    naimenovanie_sk6: '',
    status_oborudovaniya6: '',
    tip_sk_po_dogovoru6: ''
  });
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const [addressQuery, setAddressQuery] = useState('');
  const [addressResults, setAddressResults] = useState([]);
  const [showAddressDropdown, setShowAddressDropdown] = useState(false);
  const [selectedAddress, setSelectedAddress] = useState(null);
  const addressInputRef = useRef(null);

  useEffect(() => {
    loadData();
  }, []);

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (addressInputRef.current && !addressInputRef.current.contains(event.target)) {
        setShowAddressDropdown(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
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

  const handleAddressSearch = async (query) => {
    setAddressQuery(query);
    setSelectedAddress(null);
    
    setFormData(prev => ({
      ...prev,
      id_ploshadki: '',
      servisnyy_id: '',
      rayon: '',
      planovaya_data_1_kv_2026: '',
      id_sk1: '', naimenovanie_sk1: '', status_oborudovaniya1: '', tip_sk_po_dogovoru1: '',
      id_sk2: '', naimenovanie_sk2: '', status_oborudovaniya2: '', tip_sk_po_dogovoru2: '',
      id_sk3: '', naimenovanie_sk3: '', status_oborudovaniya3: '', tip_sk_po_dogovoru3: '',
      id_sk4: '', naimenovanie_sk4: '', status_oborudovaniya4: '', tip_sk_po_dogovoru4: '',
      id_sk5: '', naimenovanie_sk5: '', status_oborudovaniya5: '', tip_sk_po_dogovoru5: '',
      id_sk6: '', naimenovanie_sk6: '', status_oborudovaniya6: '', tip_sk_po_dogovoru6: ''
    }));

    if (query.length < 2) {
      setAddressResults([]);
      return;
    }

    try {
      const result = await installationsApi.searchAddresses(query);
      setAddressResults(result.addresses || []);
      setShowAddressDropdown(true);
    } catch (err) {
      console.error('Search addresses error:', err);
      setAddressResults([]);
    }
  };

  const handleSelectAddress = (address) => {
    setSelectedAddress(address);
    setAddressQuery(address.adres_razmeshcheniya);
    setShowAddressDropdown(false);

    const skData = address.sk || [];
    
    setFormData(prev => ({
      ...prev,
      address: address.adres_razmeshcheniya,
      id_ploshadki: address.id_ploshadki?.toString() || '',
      servisnyy_id: address.servisnyy_id || '',
      rayon: address.rayon || '',
      planovaya_data_1_kv_2026: address.planovaya_data_1_kv_2026 || '',
      id_sk1: skData[0]?.id_sk?.toString() || '',
      naimenovanie_sk1: skData[0]?.naimenovanie_sk || '',
      status_oborudovaniya1: skData[0]?.status_oborudovaniya || '',
      tip_sk_po_dogovoru1: skData[0]?.tip_sk_po_dogovoru?.toString() || '',
      id_sk2: skData[1]?.id_sk?.toString() || '',
      naimenovanie_sk2: skData[1]?.naimenovanie_sk || '',
      status_oborudovaniya2: skData[1]?.status_oborudovaniya || '',
      tip_sk_po_dogovoru2: skData[1]?.tip_sk_po_dogovoru?.toString() || '',
      id_sk3: skData[2]?.id_sk?.toString() || '',
      naimenovanie_sk3: skData[2]?.naimenovanie_sk || '',
      status_oborudovaniya3: skData[2]?.status_oborudovaniya || '',
      tip_sk_po_dogovoru3: skData[2]?.tip_sk_po_dogovoru?.toString() || '',
      id_sk4: skData[3]?.id_sk?.toString() || '',
      naimenovanie_sk4: skData[3]?.naimenovanie_sk || '',
      status_oborudovaniya4: skData[3]?.status_oborudovaniya || '',
      tip_sk_po_dogovoru4: skData[3]?.tip_sk_po_dogovoru?.toString() || '',
      id_sk5: skData[4]?.id_sk?.toString() || '',
      naimenovanie_sk5: skData[4]?.naimenovanie_sk || '',
      status_oborudovaniya5: skData[4]?.status_oborudovaniya || '',
      tip_sk_po_dogovoru5: skData[4]?.tip_sk_po_dogovoru?.toString() || '',
      id_sk6: skData[5]?.id_sk?.toString() || '',
      naimenovanie_sk6: skData[5]?.naimenovanie_sk || '',
      status_oborudovaniya6: skData[5]?.status_oborudovaniya || '',
      tip_sk_po_dogovoru6: skData[5]?.tip_sk_po_dogovoru?.toString() || ''
    }));
  };

  const getSkCount = () => {
    let count = 0;
    for (let i = 1; i <= 6; i++) {
      if (formData[`id_sk${i}`]) count++;
    }
    return count;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    e.stopPropagation();
    setError('');
    setSubmitting(false);
    
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
        received_at: '',
        id_ploshadki: '',
        servisnyy_id: '',
        rayon: '',
        planovaya_data_1_kv_2026: '',
        id_sk1: '', naimenovanie_sk1: '', status_oborudovaniya1: '', tip_sk_po_dogovoru1: '',
        id_sk2: '', naimenovanie_sk2: '', status_oborudovaniya2: '', tip_sk_po_dogovoru2: '',
        id_sk3: '', naimenovanie_sk3: '', status_oborudovaniya3: '', tip_sk_po_dogovoru3: '',
        id_sk4: '', naimenovanie_sk4: '', status_oborudovaniya4: '', tip_sk_po_dogovoru4: '',
        id_sk5: '', naimenovanie_sk5: '', status_oborudovaniya5: '', tip_sk_po_dogovoru5: '',
        id_sk6: '', naimenovanie_sk6: '', status_oborudovaniya6: '', tip_sk_po_dogovoru6: ''
      });
      setAddressQuery('');
      setSelectedAddress(null);
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
    setAddressQuery(installation.address || '');
    setSelectedAddress(installation.address ? { adres_razmeshcheniya: installation.address } : null);
    
    setFormData({
      project_id: installation.project_id || '',
      title: installation.title || '',
      description: installation.description || '',
      assignee_id: installation.assignee_id || '',
      status: installation.status || 'new',
      scheduled_at: installation.scheduled_at ? installation.scheduled_at.slice(0, 16) : '',
      address: installation.address || '',
      receipt_address: installation.receipt_address || '',
      received_at: installation.received_at ? installation.received_at.slice(0, 16) : '',
      id_ploshadki: installation.id_ploshadki?.toString() || '',
      servisnyy_id: installation.servisnyy_id || '',
      rayon: installation.rayon || '',
      planovaya_data_1_kv_2026: installation.planovaya_data_1_kv_2026 || '',
      id_sk1: installation.id_sk1?.toString() || '',
      naimenovanie_sk1: installation.naimenovanie_sk1 || '',
      status_oborudovaniya1: installation.status_oborudovaniya1 || '',
      tip_sk_po_dogovoru1: installation.tip_sk_po_dogovoru1?.toString() || '',
      id_sk2: installation.id_sk2?.toString() || '',
      naimenovanie_sk2: installation.naimenovanie_sk2 || '',
      status_oborudovaniya2: installation.status_oborudovaniya2 || '',
      tip_sk_po_dogovoru2: installation.tip_sk_po_dogovoru2?.toString() || '',
      id_sk3: installation.id_sk3?.toString() || '',
      naimenovanie_sk3: installation.naimenovanie_sk3 || '',
      status_oborudovaniya3: installation.status_oborudovaniya3 || '',
      tip_sk_po_dogovoru3: installation.tip_sk_po_dogovoru3?.toString() || '',
      id_sk4: installation.id_sk4?.toString() || '',
      naimenovanie_sk4: installation.naimenovanie_sk4 || '',
      status_oborudovaniya4: installation.status_oborudovaniya4 || '',
      tip_sk_po_dogovoru4: installation.tip_sk_po_dogovoru4?.toString() || '',
      id_sk5: installation.id_sk5?.toString() || '',
      naimenovanie_sk5: installation.naimenovanie_sk5 || '',
      status_oborudovaniya5: installation.status_oborudovaniya5 || '',
      tip_sk_po_dogovoru5: installation.tip_sk_po_dogovoru5?.toString() || '',
      id_sk6: installation.id_sk6?.toString() || '',
      naimenovanie_sk6: installation.naimenovanie_sk6 || '',
      status_oborudovaniya6: installation.status_oborudovaniya6 || '',
      tip_sk_po_dogovoru6: installation.tip_sk_po_dogovoru6?.toString() || ''
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
    setAddressQuery('');
    setSelectedAddress(null);
    setFormData({
      project_id: '',
      title: '',
      description: '',
      assignee_id: '',
      status: 'new',
      scheduled_at: '',
      address: '',
      receipt_address: '',
      received_at: '',
      id_ploshadki: '',
      servisnyy_id: '',
      rayon: '',
      planovaya_data_1_kv_2026: '',
      id_sk1: '', naimenovanie_sk1: '', status_oborudovaniya1: '', tip_sk_po_dogovoru1: '',
      id_sk2: '', naimenovanie_sk2: '', status_oborudovaniya2: '', tip_sk_po_dogovoru2: '',
      id_sk3: '', naimenovanie_sk3: '', status_oborudovaniya3: '', tip_sk_po_dogovoru3: '',
      id_sk4: '', naimenovanie_sk4: '', status_oborudovaniya4: '', tip_sk_po_dogovoru4: '',
      id_sk5: '', naimenovanie_sk5: '', status_oborudovaniya5: '', tip_sk_po_dogovoru5: '',
      id_sk6: '', naimenovanie_sk6: '', status_oborudovaniya6: '', tip_sk_po_dogovoru6: ''
    });
    setShowModal(true);
  };

  const handleStatusChangeClick = (installationId, currentStatus) => {
    if (currentStatus === 'ready_for_receipt' || currentStatus === 'received') {
      const installation = installations.find(i => i.id === installationId);
      setStatusChangeData({
        installationId,
        newStatus: currentStatus,
        receipt_address: installation?.receipt_address || '',
        received_at: installation?.received_at ? installation.received_at.slice(0, 16) : ''
      });
      setShowStatusModal(true);
    } else {
      handleStatusChangeSimple(installationId, currentStatus);
    }
  };

  const handleStatusChangeSimple = async (installationId, newStatus) => {
    try {
      await installationsApi.update(installationId, { status: newStatus });
      loadData();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleStatusChange = async () => {
    try {
      const { installationId, newStatus, receipt_address, received_at } = statusChangeData;
      await installationsApi.update(installationId, { 
        status: newStatus,
        receipt_address: newStatus === 'ready_for_receipt' || newStatus === 'received' ? receipt_address : null,
        received_at: newStatus === 'received' ? received_at : null
      });
      setShowStatusModal(false);
      setStatusChangeData({
        installationId: null,
        newStatus: '',
        receipt_address: '',
        received_at: ''
      });
      loadData();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleArchiveInstallation = async (installationId) => {
    try {
      await installationsApi.update(installationId, { is_archived: true });
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

  const skCount = getSkCount();

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
          <Link to="/archive">РђСЂС…РёРІ</Link>
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
                        onChange={(e) => handleStatusChangeClick(inst.id, e.target.value)}
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
                              className="btn btn-secondary" 
                              onClick={() => handleArchiveInstallation(inst.id)}
                              style={{ padding: '5px 10px', fontSize: '12px' }}
                              title="РџРµСЂРµРјРµСЃС‚РёС‚СЊ РІ Р°СЂС…РёРІ"
                            >
                              Р’ Р°СЂС…РёРІ
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
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: '800px', maxHeight: '90vh', overflowY: 'auto' }}>
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

              {/* Address Search Section */}
              <div className="form-group" style={{ position: 'relative' }} ref={addressInputRef}>
                <label>РџРѕРёСЃРє Р°РґСЂРµСЃР° (Q1 2026)</label>
                <input
                  type="text"
                  value={addressQuery}
                  onChange={e => handleAddressSearch(e.target.value)}
                  placeholder="Р’РІРµРґРёС‚Рµ Р°РґСЂРµСЃ РґР»СЏ РїРѕРёСЃРєР°..."
                  autoComplete="off"
                />
                {showAddressDropdown && addressResults.length > 0 && (
                  <ul style={{
                    position: 'absolute',
                    top: '100%',
                    left: 0,
                    right: 0,
                    background: 'white',
                    border: '1px solid #ddd',
                    borderRadius: '4px',
                    maxHeight: '200px',
                    overflowY: 'auto',
                    listStyle: 'none',
                    padding: 0,
                    margin: 0,
                    zIndex: 1000
                  }}>
                    {addressResults.map((addr, idx) => (
                      <li key={idx}
                        onClick={() => handleSelectAddress(addr)}
                        style={{
                          padding: '10px',
                          cursor: 'pointer',
                          borderBottom: '1px solid #eee'
                        }}
                      >
                        <div>{addr.adres_razmeshcheniya}</div>
                        <div style={{ fontSize: '12px', color: '#666' }}>
                          Р Р°Р№РѕРЅ: {addr.rayon} | РЎРљ: {addr.sk_count} | ID: {addr.id_ploshadki}
                        </div>
                      </li>
                    ))}
                  </ul>
                )}
              </div>

              <div className="form-group">
                <label>РђРґСЂРµСЃ</label>
                <input
                  type="text"
                  value={formData.address}
                  onChange={e => setFormData({ ...formData, address: e.target.value })}
                />
              </div>

              {/* SK Fields - ReadOnly when selected from search */}
              <fieldset style={{ border: '1px solid #ddd', padding: '15px', marginBottom: '15px' }}>
                <legend style={{ fontWeight: 'bold', color: '#333' }}>Р”Р°РЅРЅС‹Рµ Рѕ РїР»РѕС‰Р°РґРєРµ (РёР· Q1 2026)</legend>
                
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                  <div className="form-group">
                    <label>ID РїР»РѕС‰Р°РґРєРё</label>
                    <input
                      type="text"
                      value={formData.id_ploshadki}
                      readOnly
                      style={{ backgroundColor: '#f5f5f5' }}
                    />
                  </div>
                  <div className="form-group">
                    <label>РЎРµСЂРІРёСЃРЅС‹Р№ ID</label>
                    <input
                      type="text"
                      value={formData.servisnyy_id}
                      readOnly
                      style={{ backgroundColor: '#f5f5f5' }}
                    />
                  </div>
                  <div className="form-group">
                    <label>Р Р°Р№РѕРЅ</label>
                    <input
                      type="text"
                      value={formData.rayon}
                      readOnly
                      style={{ backgroundColor: '#f5f5f5' }}
                    />
                  </div>
                  <div className="form-group">
                    <label>РџР»Р°РЅРѕРІР°СЏ РґР°С‚Р° 1 РєРІ. 2026</label>
                    <input
                      type="text"
                      value={formData.planovaya_data_1_kv_2026}
                      readOnly
                      style={{ backgroundColor: '#f5f5f5' }}
                    />
                  </div>
                </div>
              </fieldset>

              {/* Dynamic SK Rows */}
              {skCount > 0 && (
                <fieldset style={{ border: '1px solid #ddd', padding: '15px', marginBottom: '15px' }}>
                  <legend style={{ fontWeight: 'bold', color: '#333' }}>РЎРёСЃС‚РµРјС‹ РєРѕРЅС‚СЂРѕР»СЏ (РЎРљ)</legend>
                  
                  {/* SK1 */}
                  {formData.id_sk1 && (
                    <div style={{ marginBottom: '15px', padding: '10px', backgroundColor: '#f9f9f9', borderRadius: '4px' }}>
                      <h4 style={{ margin: '0 0 10px 0' }}>РЎРљ #1</h4>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                        <div className="form-group">
                          <label>ID РЎРљ</label>
                          <input type="text" value={formData.id_sk1} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РќР°РёРјРµРЅРѕРІР°РЅРёРµ РЎРљ</label>
                          <input type="text" value={formData.naimenovanie_sk1} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РЎС‚Р°С‚СѓСЃ РѕР±РѕСЂСѓРґРѕРІР°РЅРёСЏ</label>
                          <input type="text" value={formData.status_oborudovaniya1} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РўРёРї РЎРљ РїРѕ РґРѕРіРѕРІРѕСЂСѓ</label>
                          <input type="text" value={formData.tip_sk_po_dogovoru1} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                      </div>
                    </div>
                  )}

                  {/* SK2 */}
                  {formData.id_sk2 && (
                    <div style={{ marginBottom: '15px', padding: '10px', backgroundColor: '#f9f9f9', borderRadius: '4px' }}>
                      <h4 style={{ margin: '0 0 10px 0' }}>РЎРљ #2</h4>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                        <div className="form-group">
                          <label>ID РЎРљ</label>
                          <input type="text" value={formData.id_sk2} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РќР°РёРјРµРЅРѕРІР°РЅРёРµ РЎРљ</label>
                          <input type="text" value={formData.naimenovanie_sk2} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РЎС‚Р°С‚СѓСЃ РѕР±РѕСЂСѓРґРѕРІР°РЅРёСЏ</label>
                          <input type="text" value={formData.status_oborudovaniya2} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РўРёРї РЎРљ РїРѕ РґРѕРіРѕРІРѕСЂСѓ</label>
                          <input type="text" value={formData.tip_sk_po_dogovoru2} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                      </div>
                    </div>
                  )}

                  {/* SK3 */}
                  {formData.id_sk3 && (
                    <div style={{ marginBottom: '15px', padding: '10px', backgroundColor: '#f9f9f9', borderRadius: '4px' }}>
                      <h4 style={{ margin: '0 0 10px 0' }}>РЎРљ #3</h4>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                        <div className="form-group">
                          <label>ID РЎРљ</label>
                          <input type="text" value={formData.id_sk3} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РќР°РёРјРµРЅРѕРІР°РЅРёРµ РЎРљ</label>
                          <input type="text" value={formData.naimenovanie_sk3} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РЎС‚Р°С‚СѓСЃ РѕР±РѕСЂСѓРґРѕРІР°РЅРёСЏ</label>
                          <input type="text" value={formData.status_oborudovaniya3} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РўРёРї РЎРљ РїРѕ РґРѕРіРѕРІРѕСЂСѓ</label>
                          <input type="text" value={formData.tip_sk_po_dogovoru3} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                      </div>
                    </div>
                  )}

                  {/* SK4 */}
                  {formData.id_sk4 && (
                    <div style={{ marginBottom: '15px', padding: '10px', backgroundColor: '#f9f9f9', borderRadius: '4px' }}>
                      <h4 style={{ margin: '0 0 10px 0' }}>РЎРљ #4</h4>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                        <div className="form-group">
                          <label>ID РЎРљ</label>
                          <input type="text" value={formData.id_sk4} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РќР°РёРјРµРЅРѕРІР°РЅРёРµ РЎРљ</label>
                          <input type="text" value={formData.naimenovanie_sk4} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РЎС‚Р°С‚СѓСЃ РѕР±РѕСЂСѓРґРѕРІР°РЅРёСЏ</label>
                          <input type="text" value={formData.status_oborudovaniya4} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РўРёРї РЎРљ РїРѕ РґРѕРіРѕРІРѕСЂСѓ</label>
                          <input type="text" value={formData.tip_sk_po_dogovoru4} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                      </div>
                    </div>
                  )}

                  {/* SK5 */}
                  {formData.id_sk5 && (
                    <div style={{ marginBottom: '15px', padding: '10px', backgroundColor: '#f9f9f9', borderRadius: '4px' }}>
                      <h4 style={{ margin: '0 0 10px 0' }}>РЎРљ #5</h4>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                        <div className="form-group">
                          <label>ID РЎРљ</label>
                          <input type="text" value={formData.id_sk5} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РќР°РёРјРµРЅРѕРІР°РЅРёРµ РЎРљ</label>
                          <input type="text" value={formData.naimenovanie_sk5} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РЎС‚Р°С‚СѓСЃ РѕР±РѕСЂСѓРґРѕРІР°РЅРёСЏ</label>
                          <input type="text" value={formData.status_oborudovaniya5} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РўРёРї РЎРљ РїРѕ РґРѕРіРѕРІРѕСЂСѓ</label>
                          <input type="text" value={formData.tip_sk_po_dogovoru5} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                      </div>
                    </div>
                  )}

                  {/* SK6 */}
                  {formData.id_sk6 && (
                    <div style={{ marginBottom: '15px', padding: '10px', backgroundColor: '#f9f9f9', borderRadius: '4px' }}>
                      <h4 style={{ margin: '0 0 10px 0' }}>РЎРљ #6</h4>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                        <div className="form-group">
                          <label>ID РЎРљ</label>
                          <input type="text" value={formData.id_sk6} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РќР°РёРјРµРЅРѕРІР°РЅРёРµ РЎРљ</label>
                          <input type="text" value={formData.naimenovanie_sk6} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РЎС‚Р°С‚СѓСЃ РѕР±РѕСЂСѓРґРѕРІР°РЅРёСЏ</label>
                          <input type="text" value={formData.status_oborudovaniya6} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>РўРёРї РЎРљ РїРѕ РґРѕРіРѕРІРѕСЂСѓ</label>
                          <input type="text" value={formData.tip_sk_po_dogovoru6} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                      </div>
                    </div>
                  )}
                </fieldset>
              )}

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

      {showStatusModal && (
        <div className="modal-overlay" onClick={() => setShowStatusModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2>РР·РјРµРЅРµРЅРёРµ СЃС‚Р°С‚СѓСЃР°</h2>
              <button className="modal-close" onClick={() => setShowStatusModal(false)}>&times;</button>
            </div>
            <div style={{ padding: '20px' }}>
              {error && <div className="error">{error}</div>}
              <div className="form-group">
                <label>РЎС‚Р°С‚СѓСЃ</label>
                <select
                  value={statusChangeData.newStatus}
                  onChange={e => setStatusChangeData({ ...statusChangeData, newStatus: e.target.value })}
                >
                  <option value="ready_for_receipt">Р“РѕС‚РѕРІ Рє РїРѕР»СѓС‡РµРЅРёСЋ</option>
                  <option value="received">РџРѕР»СѓС‡РµРЅРѕ</option>
                </select>
              </div>
              <div className="form-group">
                <label>РђРґСЂРµСЃ РїРѕР»СѓС‡РµРЅРёСЏ</label>
                <input
                  type="text"
                  value={statusChangeData.receipt_address}
                  onChange={e => setStatusChangeData({ ...statusChangeData, receipt_address: e.target.value })}
                  placeholder="Р’РІРµРґРёС‚Рµ Р°РґСЂРµСЃ РїРѕР»СѓС‡РµРЅРёСЏ"
                />
              </div>
              {statusChangeData.newStatus === 'received' && (
                <div className="form-group">
                  <label>Р”Р°С‚Р° РїРѕР»СѓС‡РµРЅРёСЏ</label>
                  <input
                    type="datetime-local"
                    value={statusChangeData.received_at}
                    onChange={e => setStatusChangeData({ ...statusChangeData, received_at: e.target.value })}
                  />
                </div>
              )}
            </div>
            <div className="modal-footer">
              <button type="button" className="btn btn-secondary" onClick={() => setShowStatusModal(false)}>
                РћС‚РјРµРЅР°
              </button>
              <button type="button" className="btn btn-primary" onClick={handleStatusChange}>
                РЎРѕС…СЂР°РЅРёС‚СЊ
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Installations;

