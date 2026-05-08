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
    // SK fields
    id_ploshadki: '',
    servisnyy_id: '',
    rayon: '',
    planovaya_data_1_kv_2026: '',
    // SK1
    id_sk1: '',
    naimenovanie_sk1: '',
    status_oborudovaniya1: '',
    tip_sk_po_dogovoru1: '',
    // SK2
    id_sk2: '',
    naimenovanie_sk2: '',
    status_oborudovaniya2: '',
    tip_sk_po_dogovoru2: '',
    // SK3
    id_sk3: '',
    naimenovanie_sk3: '',
    status_oborudovaniya3: '',
    tip_sk_po_dogovoru3: '',
    // SK4
    id_sk4: '',
    naimenovanie_sk4: '',
    status_oborudovaniya4: '',
    tip_sk_po_dogovoru4: '',
    // SK5
    id_sk5: '',
    naimenovanie_sk5: '',
    status_oborudovaniya5: '',
    tip_sk_po_dogovoru5: '',
    // SK6
    id_sk6: '',
    naimenovanie_sk6: '',
    status_oborudovaniya6: '',
    tip_sk_po_dogovoru6: ''
  });
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  // Address search state
  const [addressQuery, setAddressQuery] = useState('');
  const [addressResults, setAddressResults] = useState([]);
  const [showAddressDropdown, setShowAddressDropdown] = useState(false);
  const [selectedAddress, setSelectedAddress] = useState(null);
  const addressInputRef = useRef(null);

  useEffect(() => {
    loadData();
  }, []);

  // Close dropdown when clicking outside
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

  // Search addresses
  const handleAddressSearch = async (query) => {
    setAddressQuery(query);
    setSelectedAddress(null);
    
    // Reset SK fields when query changes
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

  // Select address
  const handleSelectAddress = (address) => {
    setSelectedAddress(address);
    setAddressQuery(address.adres_razmeshcheniya);
    setShowAddressDropdown(false);

    // Fill form with address data
    const skData = address.sk || [];
    
    setFormData(prev => ({
      ...prev,
      address: address.adres_razmeshcheniya,
      id_ploshadki: address.id_ploshadki?.toString() || '',
      servisnyy_id: address.servisnyy_id || '',
      rayon: address.rayon || '',
      planovaya_data_1_kv_2026: address.planovaya_data_1_kv_2026 || '',
      // SK1
      id_sk1: skData[0]?.id_sk?.toString() || '',
      naimenovanie_sk1: skData[0]?.naimenovanie_sk || '',
      status_oborudovaniya1: skData[0]?.status_oborudovaniya || '',
      tip_sk_po_dogovoru1: skData[0]?.tip_sk_po_dogovoru?.toString() || '',
      // SK2
      id_sk2: skData[1]?.id_sk?.toString() || '',
      naimenovanie_sk2: skData[1]?.naimenovanie_sk || '',
      status_oborudovaniya2: skData[1]?.status_oborudovaniya || '',
      tip_sk_po_dogovoru2: skData[1]?.tip_sk_po_dogovoru?.toString() || '',
      // SK3
      id_sk3: skData[2]?.id_sk?.toString() || '',
      naimenovanie_sk3: skData[2]?.naimenovanie_sk || '',
      status_oborudovaniya3: skData[2]?.status_oborudovaniya || '',
      tip_sk_po_dogovoru3: skData[2]?.tip_sk_po_dogovoru?.toString() || '',
      // SK4
      id_sk4: skData[3]?.id_sk?.toString() || '',
      naimenovanie_sk4: skData[3]?.naimenovanie_sk || '',
      status_oborudovaniya4: skData[3]?.status_oborudovaniya || '',
      tip_sk_po_dogovoru4: skData[3]?.tip_sk_po_dogovoru?.toString() || '',
      // SK5
      id_sk5: skData[4]?.id_sk?.toString() || '',
      naimenovanie_sk5: skData[4]?.naimenovanie_sk || '',
      status_oborudovaniya5: skData[4]?.status_oborudovaniya || '',
      tip_sk_po_dogovoru5: skData[4]?.tip_sk_po_dogovoru?.toString() || '',
      // SK6
      id_sk6: skData[5]?.id_sk?.toString() || '',
      naimenovanie_sk6: skData[5]?.naimenovanie_sk || '',
      status_oborudovaniya6: skData[5]?.status_oborudovaniya || '',
      tip_sk_po_dogovoru6: skData[5]?.tip_sk_po_dogovoru?.toString() || ''
    }));
  };

  // Get SK count from form data
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
    
    // Validate required fields
    if (!formData.project_id || !formData.title) {
      setError('Пожалуйста, заполните обязательные поля (проект и название)');
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
      setError(err.message || 'Ошибка при создании монтажа. Проверьте консоль браузера для деталей.');
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
      // SK fields
      id_ploshadki: installation.id_ploshadki?.toString() || '',
      servisnyy_id: installation.servisnyy_id || '',
      rayon: installation.rayon || '',
      planovaya_data_1_kv_2026: installation.planovaya_data_1_kv_2026 || '',
      // SK1
      id_sk1: installation.id_sk1?.toString() || '',
      naimenovanie_sk1: installation.naimenovanie_sk1 || '',
      status_oborudovaniya1: installation.status_oborudovaniya1 || '',
      tip_sk_po_dogovoru1: installation.tip_sk_po_dogovoru1?.toString() || '',
      // SK2
      id_sk2: installation.id_sk2?.toString() || '',
      naimenovanie_sk2: installation.naimenovanie_sk2 || '',
      status_oborudovaniya2: installation.status_oborudovaniya2 || '',
      tip_sk_po_dogovoru2: installation.tip_sk_po_dogovoru2?.toString() || '',
      // SK3
      id_sk3: installation.id_sk3?.toString() || '',
      naimenovanie_sk3: installation.naimenovanie_sk3 || '',
      status_oborudovaniya3: installation.status_oborudovaniya3 || '',
      tip_sk_po_dogovoru3: installation.tip_sk_po_dogovoru3?.toString() || '',
      // SK4
      id_sk4: installation.id_sk4?.toString() || '',
      naimenovanie_sk4: installation.naimenovanie_sk4 || '',
      status_oborudovaniya4: installation.status_oborudovaniya4 || '',
      tip_sk_po_dogovoru4: installation.tip_sk_po_dogovoru4?.toString() || '',
      // SK5
      id_sk5: installation.id_sk5?.toString() || '',
      naimenovanie_sk5: installation.naimenovanie_sk5 || '',
      status_oborudovaniya5: installation.status_oborudovaniya5 || '',
      tip_sk_po_dogovoru5: installation.tip_sk_po_dogovoru5?.toString() || '',
      // SK6
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

  const skCount = getSkCount();

  if (loading) {
    return <div className="loading">Загрузка...</div>;
  }

  return (
    <div>
      <header className="header">
        <h1>Монтажи</h1>
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
            <h3 className="card-title">Список монтажей</h3>
            {isManager && (
              <button className="btn btn-primary" onClick={openCreateModal}>
                Создать монтаж
              </button>
            )}
          </div>

          {error && <div className="error">{error}</div>}

          {installations.length === 0 ? (
            <div className="empty-state">
              <h3>Нет монтажей</h3>
              <p>Создайте первый монтаж</p>
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
                  <th>Дата</th>
                  <th>Адрес</th>
                  <th>Действия</th>
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
                        <option value="new">Новый</option>
                        <option value="planned">Запланирован</option>
                        <option value="in_progress">В работе</option>
                        <option value="waiting_materials">Ожидает материалов</option>
                        <option value="in_order">В заказе</option>
                        <option value="ready_for_receipt">Готов к получению</option>
                        <option value="received">Получено</option>
                        <option value="done">Завершён</option>
                        <option value="postponed">Отложен</option>
                      </select>
                    </td>
                    <td>{inst.scheduled_at ? new Date(inst.scheduled_at).toLocaleDateString('ru-RU') : '-'}</td>
                    <td>{inst.address || '-'}</td>
                    <td>
                      <div style={{ display: 'flex', gap: '5px' }}>
                        <Link to={`/installations/${inst.id}`} className="btn btn-secondary">
                          Подробнее
                        </Link>
                        {isManager && (
                          <>
                            <button 
                              className="btn btn-primary" 
                              onClick={() => handleEdit(inst)}
                              style={{ padding: '5px 10px', fontSize: '12px' }}
                            >
                              Изменить
                            </button>
                            <button 
                              className="btn btn-secondary" 
                              onClick={() => handleArchiveInstallation(inst.id)}
                              style={{ padding: '5px 10px', fontSize: '12px' }}
                              title="Переместить в архив"
                            >
                              В архив
                            </button>
                            <button 
                              className="btn btn-danger" 
                              onClick={() => {
                                setDeletingInstallation(inst);
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
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: '800px', maxHeight: '90vh', overflowY: 'auto' }}>
            <div className="modal-header">
              <h2>{editingInstallation ? 'Редактировать монтаж' : 'Создать монтаж'}</h2>
              <button className="modal-close" onClick={() => setShowModal(false)}>&times;</button>
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
                <label>Дата монтажа</label>
                <input
                  type="datetime-local"
                  value={formData.scheduled_at}
                  onChange={e => setFormData({ ...formData, scheduled_at: e.target.value })}
                />
              </div>

              {/* Address Search Section */}
              <div className="form-group" style={{ position: 'relative' }} ref={addressInputRef}>
                <label>Поиск адреса (Q1 2026)</label>
                <input
                  type="text"
                  value={addressQuery}
                  onChange={e => handleAddressSearch(e.target.value)}
                  placeholder="Введите адрес для поиска..."
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
                          Район: {addr.rayon} | СК: {addr.sk_count} | ID: {addr.id_ploshadki}
                        </div>
                      </li>
                    ))}
                  </ul>
                )}
              </div>

              <div className="form-group">
                <label>Адрес</label>
                <input
                  type="text"
                  value={formData.address}
                  onChange={e => setFormData({ ...formData, address: e.target.value })}
                />
              </div>

              {/* SK Fields - ReadOnly when selected from search */}
              <fieldset style={{ border: '1px solid #ddd', padding: '15px', marginBottom: '15px' }}>
                <legend style={{ fontWeight: 'bold', color: '#333' }}>Данные о площадке (из Q1 2026)</legend>
                
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                  <div className="form-group">
                    <label>ID площадки</label>
                    <input
                      type="text"
                      value={formData.id_ploshadki}
                      readOnly
                      style={{ backgroundColor: '#f5f5f5' }}
                    />
                  </div>
                  <div className="form-group">
                    <label>Сервисный ID</label>
                    <input
                      type="text"
                      value={formData.servisnyy_id}
                      readOnly
                      style={{ backgroundColor: '#f5f5f5' }}
                    />
                  </div>
                  <div className="form-group">
                    <label>Район</label>
                    <input
                      type="text"
                      value={formData.rayon}
                      readOnly
                      style={{ backgroundColor: '#f5f5f5' }}
                    />
                  </div>
                  <div className="form-group">
                    <label>Плановая дата 1 кв. 2026</label>
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
                  <legend style={{ fontWeight: 'bold', color: '#333' }}>Системы контроля (СК)</legend>
                  
                  {/* SK1 */}
                  {formData.id_sk1 && (
                    <div style={{ marginBottom: '15px', padding: '10px', backgroundColor: '#f9f9f9', borderRadius: '4px' }}>
                      <h4 style={{ margin: '0 0 10px 0' }}>СК #1</h4>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                        <div className="form-group">
                          <label>ID СК</label>
                          <input type="text" value={formData.id_sk1} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Наименование СК</label>
                          <input type="text" value={formData.naimenovanie_sk1} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Статус оборудования</label>
                          <input type="text" value={formData.status_oborudovaniya1} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Тип СК по договору</label>
                          <input type="text" value={formData.tip_sk_po_dogovoru1} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                      </div>
                    </div>
                  )}

                  {/* SK2 */}
                  {formData.id_sk2 && (
                    <div style={{ marginBottom: '15px', padding: '10px', backgroundColor: '#f9f9f9', borderRadius: '4px' }}>
                      <h4 style={{ margin: '0 0 10px 0' }}>СК #2</h4>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                        <div className="form-group">
                          <label>ID СК</label>
                          <input type="text" value={formData.id_sk2} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Наименование СК</label>
                          <input type="text" value={formData.naimenovanie_sk2} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Статус оборудования</label>
                          <input type="text" value={formData.status_oborudovaniya2} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Тип СК по договору</label>
                          <input type="text" value={formData.tip_sk_po_dogovoru2} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                      </div>
                    </div>
                  )}

                  {/* SK3 */}
                  {formData.id_sk3 && (
                    <div style={{ marginBottom: '15px', padding: '10px', backgroundColor: '#f9f9f9', borderRadius: '4px' }}>
                      <h4 style={{ margin: '0 0 10px 0' }}>СК #3</h4>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                        <div className="form-group">
                          <label>ID СК</label>
                          <input type="text" value={formData.id_sk3} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Наименование СК</label>
                          <input type="text" value={formData.naimenovanie_sk3} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Статус оборудования</label>
                          <input type="text" value={formData.status_oborudovaniya3} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Тип СК по договору</label>
                          <input type="text" value={formData.tip_sk_po_dogovoru3} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                      </div>
                    </div>
                  )}

                  {/* SK4 */}
                  {formData.id_sk4 && (
                    <div style={{ marginBottom: '15px', padding: '10px', backgroundColor: '#f9f9f9', borderRadius: '4px' }}>
                      <h4 style={{ margin: '0 0 10px 0' }}>СК #4</h4>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                        <div className="form-group">
                          <label>ID СК</label>
                          <input type="text" value={formData.id_sk4} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Наименование СК</label>
                          <input type="text" value={formData.naimenovanie_sk4} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Статус оборудования</label>
                          <input type="text" value={formData.status_oborudovaniya4} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Тип СК по договору</label>
                          <input type="text" value={formData.tip_sk_po_dogovoru4} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                      </div>
                    </div>
                  )}

                  {/* SK5 */}
                  {formData.id_sk5 && (
                    <div style={{ marginBottom: '15px', padding: '10px', backgroundColor: '#f9f9f9', borderRadius: '4px' }}>
                      <h4 style={{ margin: '0 0 10px 0' }}>СК #5</h4>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                        <div className="form-group">
                          <label>ID СК</label>
                          <input type="text" value={formData.id_sk5} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Наименование СК</label>
                          <input type="text" value={formData.naimenovanie_sk5} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Статус оборудования</label>
                          <input type="text" value={formData.status_oborudovaniya5} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Тип СК по договору</label>
                          <input type="text" value={formData.tip_sk_po_dogovoru5} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                      </div>
                    </div>
                  )}

                  {/* SK6 */}
                  {formData.id_sk6 && (
                    <div style={{ marginBottom: '15px', padding: '10px', backgroundColor: '#f9f9f9', borderRadius: '4px' }}>
                      <h4 style={{ margin: '0 0 10px 0' }}>СК #6</h4>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                        <div className="form-group">
                          <label>ID СК</label>
                          <input type="text" value={formData.id_sk6} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Наименование СК</label>
                          <input type="text" value={formData.naimenovanie_sk6} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Статус оборудования</label>
                          <input type="text" value={formData.status_oborudovaniya6} readOnly style={{ backgroundColor: '#f5f5f5' }} />
                        </div>
                        <div className="form-group">
                          <label>Тип СК по договору</label>
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
                    <label>Адрес получения</label>
                    <input
                      type="text"
                      value={formData.receipt_address}
                      onChange={e => setFormData({ ...formData, receipt_address: e.target.value })}
                      placeholder="Введите адрес получения"
                    />
                  </div>
                  {formData.status === 'received' && (
                    <div className="form-group">
                      <label>Дата получения</label>
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
                  Отмена
                </button>
                <button type="submit" className="btn btn-primary" disabled={submitting}>
                  {submitting ? 'Сохранение...' : (editingInstallation ? 'Сохранить' : 'Создать')}
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
              <p>Вы уверены, что хотите удалить монтаж "{deletingInstallation?.title}"?</p>
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

      {showStatusModal && (
        <div className="modal-overlay" onClick={() => setShowStatusModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Изменение статуса</h2>
              <button className="modal-close" onClick={() => setShowStatusModal(false)}>&times;</button>
            </div>
            <div style={{ padding: '20px' }}>
              {error && <div className="error">{error}</div>}
              <div className="form-group">
                <label>Статус</label>
                <select
                  value={statusChangeData.newStatus}
                  onChange={e => setStatusChangeData({ ...statusChangeData, newStatus: e.target.value })}
                >
                  <option value="ready_for_receipt">Готов к получению</option>
                  <option value="received">Получено</option>
                </select>
              </div>
              <div className="form-group">
                <label>Адрес получения</label>
                <input
                  type="text"
                  value={statusChangeData.receipt_address}
                  onChange={e => setStatusChangeData({ ...statusChangeData, receipt_address: e.target.value })}
                  placeholder="Введите адрес получения"
                />
              </div>
              {statusChangeData.newStatus === 'received' && (
                <div className="form-group">
                  <label>Дата получения</label>
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
                Отмена
              </button>
              <button type="button" className="btn btn-primary" onClick={handleStatusChange}>
                Сохранить
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Installations;

