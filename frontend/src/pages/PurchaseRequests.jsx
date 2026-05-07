import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { purchaseRequestsApi, tasksApi, installationsApi, materialsApi } from '../api';

const PurchaseRequests = () => {
  const { isManager, isWorker, user } = useAuth();
  const [requests, setRequests] = useState([]);
  const [tasks, setTasks] = useState([]);
  const [installations, setInstallations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');
  const [error, setError] = useState('');
  
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showItemsModal, setShowItemsModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [showRejectModal, setShowRejectModal] = useState(false);
  const [selectedRequest, setSelectedRequest] = useState(null);
  const [editingItem, setEditingItem] = useState(null);
  const [editingRequest, setEditingRequest] = useState(null);
  const [rejectReason, setRejectReason] = useState('');
  
  const [formData, setFormData] = useState({
    task_id: '',
    installation_id: '',
    comment: '',
    status: 'draft'
  });
  
  const [itemFormData, setItemFormData] = useState({
    name: '',
    quantity: 1,
    unit: 'С€С‚'
  });
  
  const [materialSearch, setMaterialSearch] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [searching, setSearching] = useState(false);
  const [showSearchResults, setShowSearchResults] = useState(false);

  useEffect(() => {
    loadRequests();
    loadRelatedData();
  }, [filter]);

  const loadRequests = async () => {
    try {
      const filters = filter !== 'all' ? { status: filter } : {};
      const data = await purchaseRequestsApi.getAll(filters);
      setRequests(data.purchaseRequests || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const loadRelatedData = async () => {
    try {
      const [tasksData, installationsData] = await Promise.all([
        tasksApi.getAll(),
        installationsApi.getAll()
      ]);
      setTasks(tasksData.tasks || []);
      setInstallations(installationsData.installations || []);
    } catch (err) {
      console.error('Error loading related data:', err);
    }
  };

  const handleCreateRequest = async (e) => {
    e.preventDefault();
    setError('');
    try {
      await purchaseRequestsApi.create(formData);
      setShowCreateModal(false);
      setFormData({ task_id: '', installation_id: '', comment: '', status: 'draft' });
      loadRequests();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleAddItem = async (e) => {
    e.preventDefault();
    setError('');
    try {
      await purchaseRequestsApi.addItem(selectedRequest.id, itemFormData);
      setItemFormData({ name: '', quantity: 1, unit: 'С€С‚' });
      setMaterialSearch('');
      setSearchResults([]);
      setShowSearchResults(false);
      loadRequests();
      const data = await purchaseRequestsApi.getById(selectedRequest.id);
      setSelectedRequest(data.purchaseRequest);
    } catch (err) {
      setError(err.message);
    }
  };

  const handleUpdateItem = async (e) => {
    e.preventDefault();
    setError('');
    try {
      await purchaseRequestsApi.updateItem(editingItem.id, itemFormData);
      setEditingItem(null);
      setItemFormData({ name: '', quantity: 1, unit: 'С€С‚' });
      setMaterialSearch('');
      setSearchResults([]);
      setShowSearchResults(false);
      loadRequests();
      const data = await purchaseRequestsApi.getById(selectedRequest.id);
      setSelectedRequest(data.purchaseRequest);
    } catch (err) {
      setError(err.message);
    }
  };

  const handleMaterialSearch = async (searchTerm) => {
    setMaterialSearch(searchTerm);
    if (searchTerm.length < 2) {
      setSearchResults([]);
      setShowSearchResults(false);
      return;
    }
    setSearching(true);
    try {
      const data = await materialsApi.search(searchTerm);
      setSearchResults(data.materials || []);
      setShowSearchResults(true);
    } catch (err) {
      console.error('Error searching materials:', err);
    } finally {
      setSearching(false);
    }
  };

  const handleSelectMaterial = (material) => {
    setItemFormData({
      ...itemFormData,
      name: material.name,
      unit: material.default_unit || 'С€С‚'
    });
    setMaterialSearch(material.name);
    setSearchResults([]);
    setShowSearchResults(false);
  };

  const handleDeleteItem = async (itemId) => {
    if (!window.confirm('Р’С‹ СѓРІРµСЂРµРЅС‹, С‡С‚Рѕ С…РѕС‚РёС‚Рµ СѓРґР°Р»РёС‚СЊ СЌС‚РѕС‚ item?')) return;
    setError('');
    try {
      await purchaseRequestsApi.deleteItem(itemId);
      loadRequests();
      const data = await purchaseRequestsApi.getById(selectedRequest.id);
      setSelectedRequest(data.purchaseRequest);
    } catch (err) {
      setError(err.message);
    }
  };

  const openItemsModal = async (request) => {
    try {
      const data = await purchaseRequestsApi.getById(request.id);
      setSelectedRequest(data.purchaseRequest);
      setShowItemsModal(true);
    } catch (err) {
      setError(err.message);
    }
  };

  const handleStatusChange = async (requestId, newStatus, comment) => {
    try {
      await purchaseRequestsApi.updateStatus(requestId, newStatus, comment);
      loadRequests();
    } catch (err) {
      setError(err.message);
    }
  };

  const getStatusLabel = (status) => {
    const labels = {
      draft: 'Р§РµСЂРЅРѕРІРёРє',
      pending: 'РћР¶РёРґР°РµС‚',
      approved: 'РџРѕРґС‚РІРµСЂР¶РґРµРЅР°',
      rejected: 'РћС‚РєР»РѕРЅРµРЅР°',
      in_order: 'Р’ Р·Р°РєР°Р·Рµ',
      ready_for_receipt: 'Р“РѕС‚РѕРІ Рє РїРѕР»СѓС‡РµРЅРёСЋ',
      received: 'РџРѕР»СѓС‡РµРЅРѕ',
      done: 'Р—Р°РІРµСЂС€С‘РЅ',
      postponed: 'РћС‚Р»РѕР¶РµРЅ'
    };
    return labels[status] || status;
  };

  const getRelatedName = (request) => {
    if (request.task) {
      const projectName = request.task.project?.name;
      return projectName 
        ? `Р—Р°РґР°С‡Р°: ${request.task.title} (РџСЂРѕРµРєС‚: ${projectName})`
        : `Р—Р°РґР°С‡Р°: ${request.task.title}`;
    }
    if (request.installation) {
      const projectName = request.installation.project?.name;
      return projectName 
        ? `РњРѕРЅС‚Р°Р¶: ${request.installation.title} (РџСЂРѕРµРєС‚: ${projectName})`
        : `РњРѕРЅС‚Р°Р¶: ${request.installation.title}`;
    }
    return '-';
  };

  const canManageItems = isWorker || isManager;

  const openEditModal = (request) => {
    setEditingRequest(request);
    setFormData({
      task_id: request.task_id || '',
      installation_id: request.installation_id || '',
      comment: request.comment || '',
      status: request.status
    });
    setShowEditModal(true);
  };

  const handleEditRequest = async (e) => {
    e.preventDefault();
    setError('');
    try {
      await purchaseRequestsApi.update(editingRequest.id, formData);
      setShowEditModal(false);
      setEditingRequest(null);
      setFormData({ task_id: '', installation_id: '', comment: '', status: 'draft' });
      loadRequests();
    } catch (err) {
      setError(err.message);
    }
  };

  const openDetailModal = async (request) => {
    try {
      const data = await purchaseRequestsApi.getById(request.id);
      setSelectedRequest(data.purchaseRequest);
      setShowDetailModal(true);
    } catch (err) {
      setError(err.message);
    }
  };

  const handleApprove = async () => {
    if (!selectedRequest) return;
    setError('');
    try {
      await purchaseRequestsApi.updateStatus(selectedRequest.id, 'approved', '');
      setShowDetailModal(false);
      setSelectedRequest(null);
      loadRequests();
    } catch (err) {
      setError(err.message);
    }
  };

  const openRejectModal = () => {
    setRejectReason('');
    setShowRejectModal(true);
  };

  const handleReject = async () => {
    if (!selectedRequest) return;
    setError('');
    try {
      await purchaseRequestsApi.updateStatus(selectedRequest.id, 'rejected', rejectReason);
      setShowRejectModal(false);
      setShowDetailModal(false);
      setSelectedRequest(null);
      setRejectReason('');
      loadRequests();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleSubmitForReview = async () => {
    if (!selectedRequest) return;
    setError('');
    try {
      await purchaseRequestsApi.updateStatus(selectedRequest.id, 'pending', '');
      setShowDetailModal(false);
      setSelectedRequest(null);
      loadRequests();
    } catch (err) {
      setError(err.message);
    }
  };

  if (loading) {
    return <div className="loading">Р—Р°РіСЂСѓР·РєР°...</div>;
  }

  return (
    <div>
      <header className="header">
        <h1>Р—Р°СЏРІРєРё РЅР° Р·Р°РєСѓРїРєСѓ</h1>
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
            <h3 className="card-title">РЎРїРёСЃРѕРє Р·Р°СЏРІРѕРє</h3>
            <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
              <select
                value={filter}
                onChange={(e) => setFilter(e.target.value)}
                style={{ padding: '8px', borderRadius: '4px', border: '1px solid #e0e0e0' }}
              >
                <option value="all">Р’СЃРµ</option>
                <option value="draft">Р§РµСЂРЅРѕРІРёРєРё</option>
                <option value="pending">РћР¶РёРґР°СЋС‰РёРµ</option>
                <option value="approved">РџРѕРґС‚РІРµСЂР¶РґС‘РЅРЅС‹Рµ</option>
                <option value="rejected">РћС‚РєР»РѕРЅС‘РЅРЅС‹Рµ</option>
                <option value="in_order">Р’ Р·Р°РєР°Р·Рµ</option>
                <option value="ready_for_receipt">Р“РѕС‚РѕРІ Рє РїРѕР»СѓС‡РµРЅРёСЋ</option>
                <option value="received">РџРѕР»СѓС‡РµРЅРѕ</option>
                <option value="done">Р—Р°РІРµСЂС€С‘РЅРЅС‹Рµ</option>
                <option value="postponed">РћС‚Р»РѕР¶РµРЅРЅС‹Рµ</option>
              </select>
              {canManageItems && (
                <button className="btn btn-primary" onClick={() => setShowCreateModal(true)}>
                  РЎРѕР·РґР°С‚СЊ Р·Р°СЏРІРєСѓ
                </button>
              )}
            </div>
          </div>

          {error && <div className="error">{error}</div>}

          {requests.length === 0 ? (
            <div className="empty-state">
              <h3>РќРµС‚ Р·Р°СЏРІРѕРє</h3>
              <p>Р—Р°СЏРІРєРё РЅР° Р·Р°РєСѓРїРєСѓ РјР°С‚РµСЂРёР°Р»РѕРІ РїРѕСЏРІСЏС‚СЃСЏ Р·РґРµСЃСЊ</p>
            </div>
          ) : (
            <table className="table">
              <thead>
                <tr>
                  <th>РЎРІСЏР·Р°РЅРЅС‹Р№ РѕР±СЉРµРєС‚</th>
                  <th>РЎРѕР·РґР°С‚РµР»СЊ</th>
                  <th>РЎС‚Р°С‚СѓСЃ</th>
                  <th>РљРѕРјРјРµРЅС‚Р°СЂРёР№</th>
                  <th>Р”Р°С‚Р° СЃРѕР·РґР°РЅРёСЏ</th>
                  <th>Р”РµР№СЃС‚РІРёСЏ</th>
                </tr>
              </thead>
              <tbody>
                {requests.map(request => (
                  <tr 
                    key={request.id} 
                    onClick={() => openDetailModal(request)}
                    style={{ cursor: 'pointer' }}
                  >
                    <td>{getRelatedName(request)}</td>
                    <td>{request.creator?.name || '-'}</td>
                    <td>
                      <span className={`status-badge status-${request.status}`}>
                        {getStatusLabel(request.status)}
                      </span>
                    </td>
                    <td>{request.comment || '-'}</td>
                    <td>{new Date(request.created_at).toLocaleDateString('ru-RU')}</td>
                    <td onClick={(e) => e.stopPropagation()}>
                      <div style={{ display: 'flex', gap: '5px', flexDirection: 'column' }}>
                        {isManager && request.status === 'pending' && (
                          <div style={{ display: 'flex', gap: '5px' }}>
                            <button
                              className="btn btn-success"
                              onClick={() => handleStatusChange(request.id, 'approved', '')}
                              style={{ padding: '5px 10px', fontSize: '12px' }}
                            >
                              РџРѕРґС‚РІРµСЂРґРёС‚СЊ
                            </button>
                            <button
                              className="btn btn-danger"
                              onClick={() => handleStatusChange(request.id, 'rejected', '')}
                              style={{ padding: '5px 10px', fontSize: '12px' }}
                            >
                              РћС‚РєР»РѕРЅРёС‚СЊ
                            </button>
                          </div>
                        )}
                        {canManageItems && (
                          <button
                            className="btn btn-secondary"
                            onClick={() => openItemsModal(request)}
                            style={{ padding: '5px 10px', fontSize: '12px' }}
                          >
                            РЈРїСЂР°РІР»РµРЅРёРµ items ({request.items?.length || 0})
                          </button>
                        )}
                        {((isManager || (isWorker && request.creator?.id === user?.id)) && (request.status === 'draft' || request.status === 'rejected')) && (
                          <button
                            className="btn btn-secondary"
                            onClick={() => openEditModal(request)}
                            style={{ padding: '5px 10px', fontSize: '12px' }}
                          >
                            Р РµРґР°РєС‚РёСЂРѕРІР°С‚СЊ
                          </button>
                        )}
                        {request.items && request.items.length > 0 && (
                          <div style={{ marginTop: '5px' }}>
                            <ul style={{ margin: '5px 0 0 15px', padding: 0 }}>
                              {request.items.slice(0, 2).map(item => (
                                <li key={item.id} style={{ fontSize: '12px' }}>
                                  {item.name} - {item.quantity} {item.unit}
                                </li>
                              ))}
                              {request.items.length > 2 && (
                                <li style={{ fontSize: '12px', color: '#757575' }}>
                                  ...РµС‰С‘ {request.items.length - 2} РїРѕР·РёС†РёР№
                                </li>
                              )}
                            </ul>
                          </div>
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

      {/* Create Request Modal */}
      {showCreateModal && (
        <div className="modal-overlay" onClick={() => setShowCreateModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2>РЎРѕР·РґР°С‚СЊ Р·Р°СЏРІРєСѓ РЅР° Р·Р°РєСѓРїРєСѓ</h2>
              <button className="modal-close" onClick={() => setShowCreateModal(false)}>&times;</button>
            </div>
            <form onSubmit={handleCreateRequest}>
              {error && <div className="error">{error}</div>}
              <div className="form-group">
                <label>РЎРІСЏР·Р°С‚СЊ СЃ Р·Р°РґР°С‡РµР№</label>
                <select
                  value={formData.task_id}
                  onChange={e => setFormData({ ...formData, task_id: e.target.value, installation_id: '' })}
                >
                  <option value="">Р’С‹Р±РµСЂРёС‚Рµ Р·Р°РґР°С‡Сѓ</option>
                  {tasks.map(task => (
                    <option key={task.id} value={task.id}>{task.title}</option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label>РЎРІСЏР·Р°С‚СЊ СЃ РјРѕРЅС‚Р°Р¶РѕРј</label>
                <select
                  value={formData.installation_id}
                  onChange={e => setFormData({ ...formData, installation_id: e.target.value, task_id: '' })}
                  disabled={!!formData.task_id}
                >
                  <option value="">Р’С‹Р±РµСЂРёС‚Рµ РјРѕРЅС‚Р°Р¶</option>
                  {installations.map(inst => (
                    <option key={inst.id} value={inst.id}>{inst.title}</option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label>РљРѕРјРјРµРЅС‚Р°СЂРёР№</label>
                <textarea
                  value={formData.comment}
                  onChange={e => setFormData({ ...formData, comment: e.target.value })}
                />
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setShowCreateModal(false)}>
                  РћС‚РјРµРЅР°
                </button>
                <button type="submit" className="btn btn-primary">
                  РЎРѕР·РґР°С‚СЊ
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Edit Request Modal */}
      {showEditModal && editingRequest && (
        <div className="modal-overlay" onClick={() => { setShowEditModal(false); setEditingRequest(null); }}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Р РµРґР°РєС‚РёСЂРѕРІР°С‚СЊ Р·Р°СЏРІРєСѓ РЅР° Р·Р°РєСѓРїРєСѓ</h2>
              <button className="modal-close" onClick={() => { setShowEditModal(false); setEditingRequest(null); }}>&times;</button>
            </div>
            <form onSubmit={handleEditRequest}>
              {error && <div className="error">{error}</div>}
              <div className="form-group">
                <label>РЎРІСЏР·Р°С‚СЊ СЃ Р·Р°РґР°С‡РµР№</label>
                <select
                  value={formData.task_id}
                  onChange={e => setFormData({ ...formData, task_id: e.target.value, installation_id: '' })}
                >
                  <option value="">Р’С‹Р±РµСЂРёС‚Рµ Р·Р°РґР°С‡Сѓ</option>
                  {tasks.map(task => (
                    <option key={task.id} value={task.id}>{task.title}</option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label>РЎРІСЏР·Р°С‚СЊ СЃ РјРѕРЅС‚Р°Р¶РѕРј</label>
                <select
                  value={formData.installation_id}
                  onChange={e => setFormData({ ...formData, installation_id: e.target.value, task_id: '' })}
                  disabled={!!formData.task_id}
                >
                  <option value="">Р’С‹Р±РµСЂРёС‚Рµ РјРѕРЅС‚Р°Р¶</option>
                  {installations.map(inst => (
                    <option key={inst.id} value={inst.id}>{inst.title}</option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label>РљРѕРјРјРµРЅС‚Р°СЂРёР№</label>
                <textarea
                  value={formData.comment}
                  onChange={e => setFormData({ ...formData, comment: e.target.value })}
                />
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => { setShowEditModal(false); setEditingRequest(null); }}>
                  РћС‚РјРµРЅР°
                </button>
                <button type="submit" className="btn btn-primary">
                  РЎРѕС…СЂР°РЅРёС‚СЊ
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Items Management Modal */}
      {showItemsModal && selectedRequest && (
        <div className="modal-overlay" onClick={() => { setShowItemsModal(false); setSelectedRequest(null); setEditingItem(null); }}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: '600px' }}>
            <div className="modal-header">
              <h2>РЈРїСЂР°РІР»РµРЅРёРµ items Р·Р°СЏРІРєРё</h2>
              <button className="modal-close" onClick={() => { setShowItemsModal(false); setSelectedRequest(null); setEditingItem(null); }}>&times;</button>
            </div>
            <div style={{ padding: '20px' }}>
              {error && <div className="error">{error}</div>}
              
              {/* Add/Edit Item Form */}
              <div style={{ marginBottom: '20px', padding: '15px', backgroundColor: '#f5f5f5', borderRadius: '4px' }}>
                <h4>{editingItem ? 'Р РµРґР°РєС‚РёСЂРѕРІР°С‚СЊ item' : 'Р”РѕР±Р°РІРёС‚СЊ item'}</h4>
                <form onSubmit={editingItem ? handleUpdateItem : handleAddItem}>
                  <div className="form-group">
                    <label>РќР°Р·РІР°РЅРёРµ *</label>
                    <div style={{ position: 'relative' }}>
                      <input
                        type="text"
                        value={editingItem ? itemFormData.name : materialSearch}
                        onChange={e => editingItem ? setItemFormData({ ...itemFormData, name: e.target.value }) : handleMaterialSearch(e.target.value)}
                        required
                        placeholder="РќР°РїСЂРёРјРµСЂ: Р‘РѕР»С‚С‹ Рњ10"
                        autoComplete="off"
                      />
                      {showSearchResults && searchResults.length > 0 && (
                        <div style={{
                          position: 'absolute',
                          top: '100%',
                          left: 0,
                          right: 0,
                          backgroundColor: 'white',
                          border: '1px solid #ddd',
                          borderRadius: '4px',
                          maxHeight: '200px',
                          overflowY: 'auto',
                          zIndex: 1000,
                          boxShadow: '0 2px 8px rgba(0,0,0,0.15)'
                        }}>
                          {searchResults.map(material => (
                            <div
                              key={material.id}
                              onClick={() => handleSelectMaterial(material)}
                              style={{
                                padding: '10px',
                                cursor: 'pointer',
                                borderBottom: '1px solid #eee',
                                display: 'flex',
                                justifyContent: 'space-between',
                                alignItems: 'center'
                              }}
                              onMouseEnter={e => e.target.style.backgroundColor = '#f5f5f5'}
                              onMouseLeave={e => e.target.style.backgroundColor = 'white'}
                            >
                              <span>{material.name}</span>
                              <span style={{ fontSize: '12px', color: '#757575' }}>
                                {material.category} вЂў {material.default_unit}
                              </span>
                            </div>
                          ))}
                        </div>
                      )}
                      {searching && (
                        <div style={{
                          position: 'absolute',
                          top: '100%',
                          left: 0,
                          right: 0,
                          padding: '10px',
                          backgroundColor: 'white',
                          border: '1px solid #ddd',
                          borderRadius: '4px',
                          fontSize: '12px',
                          color: '#757575'
                        }}>
                          РџРѕРёСЃРє...
                        </div>
                      )}
                    </div>
                    {searchResults.length > 0 && !showSearchResults && (
                      <button
                        type="button"
                        onClick={() => setShowSearchResults(true)}
                        style={{
                          marginTop: '5px',
                          fontSize: '12px',
                          color: '#1976d2',
                          background: 'none',
                          border: 'none',
                          cursor: 'pointer',
                          textDecoration: 'underline'
                        }}
                      >
                        РџРѕРєР°Р·Р°С‚СЊ РЅР°Р№РґРµРЅРЅС‹Рµ РјР°С‚РµСЂРёР°Р»С‹ ({searchResults.length})
                      </button>
                    )}
                  </div>
                  <div style={{ display: 'flex', gap: '10px' }}>
                    <div className="form-group" style={{ flex: 1 }}>
                      <label>РљРѕР»РёС‡РµСЃС‚РІРѕ *</label>
                      <input
                        type="number"
                        min="1"
                        value={itemFormData.quantity}
                        onChange={e => setItemFormData({ ...itemFormData, quantity: parseInt(e.target.value) || 1 })}
                        required
                      />
                    </div>
                    <div className="form-group" style={{ flex: 1 }}>
                      <label>Р•РґРёРЅРёС†Р°</label>
                      <select
                        value={itemFormData.unit}
                        onChange={e => setItemFormData({ ...itemFormData, unit: e.target.value })}
                      >
                        <option value="С€С‚">С€С‚</option>
                        <option value="РєРі">РєРі</option>
                        <option value="Рј">Рј</option>
                        <option value="Рј2">Рј2</option>
                        <option value="Рј3">Рј3</option>
                        <option value="СѓРїР°РєРѕРІРєР°">СѓРїР°РєРѕРІРєР°</option>
                        <option value="РєРѕРјРїР»РµРєС‚">РєРѕРјРїР»РµРєС‚</option>
                      </select>
                    </div>
                  </div>
                  <div style={{ display: 'flex', gap: '10px', marginTop: '10px' }}>
                    <button type="submit" className="btn btn-primary">
                      {editingItem ? 'РЎРѕС…СЂР°РЅРёС‚СЊ' : 'Р”РѕР±Р°РІРёС‚СЊ'}
                    </button>
                    {editingItem && (
                      <button type="button" className="btn btn-secondary" onClick={() => { setEditingItem(null); setItemFormData({ name: '', quantity: 1, unit: 'С€С‚' }); }}>
                        РћС‚РјРµРЅР°
                      </button>
                    )}
                  </div>
                </form>
              </div>

              {/* Items List */}
              <h4>РЎРїРёСЃРѕРє items</h4>
              {selectedRequest.items && selectedRequest.items.length > 0 ? (
                <table className="table">
                  <thead>
                    <tr>
                      <th>РќР°Р·РІР°РЅРёРµ</th>
                      <th>РљРѕР»РёС‡РµСЃС‚РІРѕ</th>
                      <th>Р”РµР№СЃС‚РІРёСЏ</th>
                    </tr>
                  </thead>
                  <tbody>
                    {selectedRequest.items.map(item => (
                      <tr key={item.id}>
                        <td>{item.name}</td>
                        <td>{item.quantity} {item.unit}</td>
                        <td>
                          <div style={{ display: 'flex', gap: '5px' }}>
                            <button
                              className="btn btn-primary"
                              onClick={() => { setEditingItem(item); setItemFormData({ name: item.name, quantity: item.quantity, unit: item.unit }); }}
                              style={{ padding: '5px 10px', fontSize: '12px' }}
                            >
                              РР·РјРµРЅРёС‚СЊ
                            </button>
                            <button
                              className="btn btn-danger"
                              onClick={() => handleDeleteItem(item.id)}
                              style={{ padding: '5px 10px', fontSize: '12px' }}
                            >
                              РЈРґР°Р»РёС‚СЊ
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <p style={{ color: '#757575' }}>РќРµС‚ items РІ СЌС‚РѕР№ Р·Р°СЏРІРєРµ</p>
              )}

              {/* Submit for Review Button - for workers with draft/rejected requests */}
              {isWorker && selectedRequest && selectedRequest.creator?.id === user?.id && (selectedRequest.status === 'draft' || selectedRequest.status === 'rejected') && (
                <div style={{ marginTop: '20px', paddingTop: '15px', borderTop: '1px solid #e0e0e0' }}>
                  <button
                    className="btn btn-primary"
                    onClick={async () => {
                      try {
                        await purchaseRequestsApi.updateStatus(selectedRequest.id, 'pending', '');
                        setShowItemsModal(false);
                        setSelectedRequest(null);
                        loadRequests();
                      } catch (err) {
                        setError(err.message);
                      }
                    }}
                    style={{ width: '100%' }}
                  >
                    РћС‚РїСЂР°РІРёС‚СЊ РЅР° СЂР°СЃСЃРјРѕС‚СЂРµРЅРёРµ
                  </button>
                </div>
              )}
            </div>
            <div className="modal-footer">
              <button type="button" className="btn btn-secondary" onClick={() => { setShowItemsModal(false); setSelectedRequest(null); setEditingItem(null); }}>
                Р—Р°РєСЂС‹С‚СЊ
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Detail Modal - Request Details */}
      {showDetailModal && selectedRequest && (
        <div className="modal-overlay" onClick={() => { setShowDetailModal(false); setSelectedRequest(null); }}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: '700px' }}>
            <div className="modal-header">
              <h2>Р”РµС‚Р°Р»Рё Р·Р°СЏРІРєРё</h2>
              <button className="modal-close" onClick={() => { setShowDetailModal(false); setSelectedRequest(null); }}>&times;</button>
            </div>
            <div style={{ padding: '20px' }}>
              {error && <div className="error">{error}</div>}
              
              {/* Request Info */}
              <div style={{ marginBottom: '20px' }}>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '15px', marginBottom: '15px' }}>
                  <div>
                    <strong>РЎРІСЏР·Р°РЅРЅС‹Р№ РѕР±СЉРµРєС‚:</strong>
                    <p>{getRelatedName(selectedRequest)}</p>
                  </div>
                  <div>
                    <strong>РЎС‚Р°С‚СѓСЃ:</strong>
                    <p>
                      <span className={`status-badge status-${selectedRequest.status}`}>
                        {getStatusLabel(selectedRequest.status)}
                      </span>
                    </p>
                  </div>
                  <div>
                    <strong>РЎРѕР·РґР°С‚РµР»СЊ:</strong>
                    <p>{selectedRequest.creator?.name || '-'}</p>
                  </div>
                  <div>
                    <strong>Р”Р°С‚Р° СЃРѕР·РґР°РЅРёСЏ:</strong>
                    <p>{new Date(selectedRequest.created_at).toLocaleString('ru-RU')}</p>
                  </div>
                </div>
                {selectedRequest.comment && selectedRequest.status !== 'rejected' && (
                  <div style={{ marginBottom: '15px' }}>
                    <strong>РљРѕРјРјРµРЅС‚Р°СЂРёР№:</strong>
                    <p>{selectedRequest.comment}</p>
                  </div>
                )}
                {selectedRequest.status === 'rejected' && (
                  <div style={{ marginBottom: '15px', padding: '10px', backgroundColor: '#ffebee', borderRadius: '4px' }}>
                    <strong>РџСЂРёС‡РёРЅР° РѕС‚РєР»РѕРЅРµРЅРёСЏ:</strong>
                    <p>{selectedRequest.comment || 'РџСЂРёС‡РёРЅР° РЅРµ СѓРєР°Р·Р°РЅР°'}</p>
                  </div>
                )}
              </div>

              {/* Items List */}
              <h4>РЎРїРёСЃРѕРє РїРѕР·РёС†РёР№</h4>
              {selectedRequest.items && selectedRequest.items.length > 0 ? (
                <table className="table">
                  <thead>
                    <tr>
                      <th>в„–</th>
                      <th>РќР°Р·РІР°РЅРёРµ</th>
                      <th>РљРѕР»РёС‡РµСЃС‚РІРѕ</th>
                    </tr>
                  </thead>
                  <tbody>
                    {selectedRequest.items.map((item, index) => (
                      <tr key={item.id}>
                        <td>{index + 1}</td>
                        <td>{item.name}</td>
                        <td>{item.quantity} {item.unit}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <p style={{ color: '#757575' }}>РќРµС‚ РїРѕР·РёС†РёР№ РІ СЌС‚РѕР№ Р·Р°СЏРІРєРµ</p>
              )}

              {/* Manager Actions */}
              {isManager && selectedRequest.status === 'pending' && (
                <div style={{ marginTop: '20px', padding: '15px', backgroundColor: '#f5f5f5', borderRadius: '4px' }}>
                  <h4>Р”РµР№СЃС‚РІРёСЏ СЂСѓРєРѕРІРѕРґРёС‚РµР»СЏ</h4>
                  <div style={{ display: 'flex', gap: '10px', marginTop: '10px' }}>
                    <button
                      className="btn btn-success"
                      onClick={handleApprove}
                    >
                      РћРґРѕР±СЂРёС‚СЊ
                    </button>
                    <button
                      className="btn btn-danger"
                      onClick={openRejectModal}
                    >
                      РћС‚РєР»РѕРЅРёС‚СЊ
                    </button>
                  </div>
                </div>
              )}

              {/* Worker Actions - Edit and Submit for Review */}
              {isWorker && selectedRequest.creator?.id === user?.id && (selectedRequest.status === 'draft' || selectedRequest.status === 'rejected') && (
                <div style={{ marginTop: '20px', padding: '15px', backgroundColor: '#e3f2fd', borderRadius: '4px' }}>
                  <h4>Р”РµР№СЃС‚РІРёСЏ РёСЃРїРѕР»РЅРёС‚РµР»СЏ</h4>
                  <p style={{ marginBottom: '10px', color: '#757575' }}>
                    Р’С‹ РјРѕР¶РµС‚Рµ РѕС‚СЂРµРґР°РєС‚РёСЂРѕРІР°С‚СЊ РїРѕР·РёС†РёРё Рё РѕС‚РїСЂР°РІРёС‚СЊ Р·Р°СЏРІРєСѓ РЅР° СЂР°СЃСЃРјРѕС‚СЂРµРЅРёРµ
                  </p>
                  <button
                    className="btn btn-primary"
                    onClick={() => {
                      setShowDetailModal(false);
                      openItemsModal(selectedRequest);
                    }}
                  >
                    Р РµРґР°РєС‚РёСЂРѕРІР°С‚СЊ Рё РѕС‚РїСЂР°РІРёС‚СЊ РЅР° СЂР°СЃСЃРјРѕС‚СЂРµРЅРёРµ
                  </button>
                </div>
              )}
            </div>
            <div className="modal-footer">
              <button type="button" className="btn btn-secondary" onClick={() => { setShowDetailModal(false); setSelectedRequest(null); }}>
                Р—Р°РєСЂС‹С‚СЊ
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Reject Reason Modal */}
      {showRejectModal && (
        <div className="modal-overlay" onClick={() => { setShowRejectModal(false); setRejectReason(''); }}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: '400px' }}>
            <div className="modal-header">
              <h2>РџСЂРёС‡РёРЅР° РѕС‚РєР»РѕРЅРµРЅРёСЏ</h2>
              <button className="modal-close" onClick={() => { setShowRejectModal(false); setRejectReason(''); }}>&times;</button>
            </div>
            <form onSubmit={(e) => { e.preventDefault(); handleReject(); }}>
              <div style={{ padding: '20px' }}>
                {error && <div className="error">{error}</div>}
                <div className="form-group">
                  <label>РЈРєР°Р¶РёС‚Рµ РїСЂРёС‡РёРЅСѓ РѕС‚РєР»РѕРЅРµРЅРёСЏ Р·Р°СЏРІРєРё:</label>
                  <textarea
                    value={rejectReason}
                    onChange={(e) => setRejectReason(e.target.value)}
                    required
                    placeholder="РќР°РїСЂРёРјРµСЂ: РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ СЃСЂРµРґСЃС‚РІ РІ Р±СЋРґР¶РµС‚Рµ"
                    style={{ minHeight: '100px' }}
                  />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => { setShowRejectModal(false); setRejectReason(''); }}>
                  РћС‚РјРµРЅР°
                </button>
                <button type="submit" className="btn btn-danger">
                  РћС‚РєР»РѕРЅРёС‚СЊ
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default PurchaseRequests;
