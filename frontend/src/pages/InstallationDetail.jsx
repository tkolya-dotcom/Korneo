import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { installationsApi, purchaseRequestsApi } from '../api';

const InstallationDetail = () => {
  const { id } = useParams();
  const { user, isManager } = useAuth();
  const [installation, setInstallation] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [items, setItems] = useState([{ name: '', quantity: 1, unit: 'pcs', note: '' }]);

  useEffect(() => {
    loadData();
  }, [id]);

  const loadData = async () => {
    try {
      const data = await installationsApi.getById(id);
      console.log('Installation data received:', data);
      console.log('All installation fields:', JSON.stringify(data.installation, null, 2));
      setInstallation(data.installation);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleStatusChange = async (newStatus) => {
    try {
      await installationsApi.update(id, { status: newStatus });
      loadData();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleCreateRequest = async () => {
    try {
      await purchaseRequestsApi.create({
        installation_id: id,
        items: items.filter(i => i.name && i.quantity)
      });
      setShowModal(false);
      setItems([{ name: '', quantity: 1, unit: 'pcs', note: '' }]);
      loadData();
    } catch (err) {
      setError(err.message);
    }
  };

  const addItem = () => {
    setItems([...items, { name: '', quantity: 1, unit: 'pcs', note: '' }]);
  };

  const updateItem = (index, field, value) => {
    const newItems = [...items];
    newItems[index][field] = value;
    setItems(newItems);
  };

  const canCreateRequest = installation && (
    installation.assignee_id === user.id || 
    isManager
  );

  if (loading) {
    return <div className="loading">Загрузка...</div>;
  }

  if (!installation) {
    return <div className="container">Монтаж не найден</div>;
  }

  return (
    <div>
      <header className="header">
        <h1>{installation.title}</h1>
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
            <h3 className="card-title">Информация о монтаже</h3>
            <Link to="/installations" className="btn btn-secondary">Назад к монтажам</Link>
          </div>
          <p><strong>Название:</strong> {installation.title}</p>
          <p><strong>Описание:</strong> {installation.description || '-'}</p>
          <p><strong>Проект:</strong> {installation.project?.name || '-'}</p>
          <p><strong>Исполнитель:</strong> {installation.assignee?.name || '-'}</p>
          <p><strong>Статус:</strong> 
            <select
              value={installation.status}
              onChange={(e) => handleStatusChange(e.target.value)}
              className={`status-badge status-${installation.status}`}
              style={{ marginLeft: '10px', border: 'none', cursor: 'pointer' }}
            >
              <option value="new">Новый</option>
              <option value="planned">Запланирован</option>
              <option value="in_progress">В работе</option>
              <option value="waiting_materials">Ожидает материалов</option>
              <option value="done">Завершён</option>
              <option value="postponed">Отложен</option>
            </select>
          </p>
          <p><strong>Дата монтажа:</strong> {installation.scheduled_at ? new Date(installation.scheduled_at).toLocaleString('ru-RU') : '-'}</p>
          <p><strong>Плановая дата:</strong> {installation.planovaya_data_1_kv_2026 ? new Date(installation.planovaya_data_1_kv_2026).toLocaleDateString('ru-RU') : '-'}</p>
          <p><strong>Адрес:</strong> {installation.address || '-'}</p>
          <p><strong>Заявка на материалы:</strong> {installation.purchaseRequests && installation.purchaseRequests.length > 0 
            ? <span style={{ color: 'green', fontWeight: 'bold' }}>✓ Создана ({installation.purchaseRequests.length})</span>
            : <span style={{ color: 'orange' }}>⊘ Не создана</span>}</p>
          <p><strong>Создан:</strong> {new Date(installation.created_at).toLocaleDateString('ru-RU')}</p>
          
          {/* SK Fields Display - проверка на существование полей */}
          {(installation.id_ploshadki !== null && installation.id_ploshadki !== undefined) || 
           (installation.servisnyy_id !== null && installation.servisnyy_id !== undefined) || 
           (installation.rayon !== null && installation.rayon !== undefined) || 
           (installation.id_sk1 !== null && installation.id_sk1 !== undefined) ? (
            <div style={{ marginTop: '20px', padding: '15px', background: '#f5f5f5', borderRadius: '4px' }}>
              <h4 style={{ marginTop: 0 }}>Информация о площадке (СК)</h4>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                {installation.id_ploshadki !== null && installation.id_ploshadki !== undefined && (
                  <p><strong>ID площадки:</strong> {installation.id_ploshadki}</p>
                )}
                {installation.servisnyy_id !== null && installation.servisnyy_id !== undefined && (
                  <p><strong>Сервисный ID:</strong> {installation.servisnyy_id}</p>
                )}
                {installation.rayon !== null && installation.rayon !== undefined && (
                  <p><strong>Район:</strong> {installation.rayon}</p>
                )}
                {installation.planovaya_data_1_kv_2026 !== null && installation.planovaya_data_1_kv_2026 !== undefined && (
                  <p><strong>Плановая дата 1 кв. 2026:</strong> {installation.planovaya_data_1_kv_2026}</p>
                )}
              </div>
              
              {/* SK1 */}
              {installation.id_sk1 !== null && installation.id_sk1 !== undefined && (
                <div style={{ marginTop: '15px', padding: '10px', background: 'white', borderRadius: '4px' }}>
                  <h5 style={{ marginTop: 0, marginBottom: '10px' }}>СК #1</h5>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                    <p><strong>ID СК:</strong> {installation.id_sk1}</p>
                    <p><strong>Наименование (марка/модель):</strong> {installation.naimenovanie_sk1 || '-'}</p>
                    <p><strong>Статус оборудования:</strong> {installation.status_oborudovaniya1 || '-'}</p>
                    <p><strong>Тип по договору:</strong> {installation.tip_sk_po_dogovoru1 || '-'}</p>
                  </div>
                </div>
              )}
              
              {/* SK2 */}
              {installation.id_sk2 !== null && installation.id_sk2 !== undefined && (
                <div style={{ marginTop: '10px', padding: '10px', background: 'white', borderRadius: '4px' }}>
                  <h5 style={{ marginTop: 0, marginBottom: '10px' }}>СК #2</h5>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                    <p><strong>ID СК:</strong> {installation.id_sk2}</p>
                    <p><strong>Наименование (марка/модель):</strong> {installation.naimenovanie_sk2 || '-'}</p>
                    <p><strong>Статус оборудования:</strong> {installation.status_oborudovaniya2 || '-'}</p>
                    <p><strong>Тип по договору:</strong> {installation.tip_sk_po_dogovoru2 || '-'}</p>
                  </div>
                </div>
              )}
              
              {/* SK3 */}
              {installation.id_sk3 !== null && installation.id_sk3 !== undefined && (
                <div style={{ marginTop: '10px', padding: '10px', background: 'white', borderRadius: '4px' }}>
                  <h5 style={{ marginTop: 0, marginBottom: '10px' }}>СК #3</h5>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                    <p><strong>ID СК:</strong> {installation.id_sk3}</p>
                    <p><strong>Наименование (марка/модель):</strong> {installation.naimenovanie_sk3 || '-'}</p>
                    <p><strong>Статус оборудования:</strong> {installation.status_oborudovaniya3 || '-'}</p>
                    <p><strong>Тип по договору:</strong> {installation.tip_sk_po_dogovoru3 || '-'}</p>
                  </div>
                </div>
              )}
              
              {/* SK4 */}
              {installation.id_sk4 !== null && installation.id_sk4 !== undefined && (
                <div style={{ marginTop: '10px', padding: '10px', background: 'white', borderRadius: '4px' }}>
                  <h5 style={{ marginTop: 0, marginBottom: '10px' }}>СК #4</h5>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                    <p><strong>ID СК:</strong> {installation.id_sk4}</p>
                    <p><strong>Наименование (марка/модель):</strong> {installation.naimenovanie_sk4 || '-'}</p>
                    <p><strong>Статус оборудования:</strong> {installation.status_oborudovaniya4 || '-'}</p>
                    <p><strong>Тип по договору:</strong> {installation.tip_sk_po_dogovoru4 || '-'}</p>
                  </div>
                </div>
              )}
              
              {/* SK5 */}
              {installation.id_sk5 !== null && installation.id_sk5 !== undefined && (
                <div style={{ marginTop: '10px', padding: '10px', background: 'white', borderRadius: '4px' }}>
                  <h5 style={{ marginTop: 0, marginBottom: '10px' }}>СК #5</h5>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                    <p><strong>ID СК:</strong> {installation.id_sk5}</p>
                    <p><strong>Наименование (марка/модель):</strong> {installation.naimenovanie_sk5 || '-'}</p>
                    <p><strong>Статус оборудования:</strong> {installation.status_oborudovaniya5 || '-'}</p>
                    <p><strong>Тип по договору:</strong> {installation.tip_sk_po_dogovoru5 || '-'}</p>
                  </div>
                </div>
              )}
              
              {/* SK6 */}
              {installation.id_sk6 !== null && installation.id_sk6 !== undefined && (
                <div style={{ marginTop: '10px', padding: '10px', background: 'white', borderRadius: '4px' }}>
                  <h5 style={{ marginTop: 0, marginBottom: '10px' }}>СК #6</h5>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                    <p><strong>ID СК:</strong> {installation.id_sk6}</p>
                    <p><strong>Наименование (марка/модель):</strong> {installation.naimenovanie_sk6 || '-'}</p>
                    <p><strong>Статус оборудования:</strong> {installation.status_oborudovaniya6 || '-'}</p>
                    <p><strong>Тип по договору:</strong> {installation.tip_sk_po_dogovoru6 || '-'}</p>
                  </div>
                </div>
              )}
            </div>
          ) : null}
          
          {canCreateRequest && (
            <button 
              className="btn btn-primary" 
              style={{ marginTop: '15px' }}
              onClick={() => setShowModal(true)}
            >
              Создать заявку на материалы
            </button>
          )}
        </div>

        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Заявки на материалы ({installation.purchaseRequests?.length || 0})</h3>
          </div>
          {(!installation.purchaseRequests || installation.purchaseRequests.length === 0) ? (
            <p>Нет заявок</p>
          ) : (
            <table className="table">
              <thead>
                <tr>
                  <th>Статус</th>
                  <th>Создатель</th>
                  <th>Подтвердил</th>
                  <th>Комментарий</th>
                  <th>Дата</th>
                </tr>
              </thead>
              <tbody>
                {installation.purchaseRequests.map(pr => (
                  <tr key={pr.id}>
                    <td>
                      <span className={`status-badge status-${pr.status}`}>
                        {pr.status}
                      </span>
                    </td>
                    <td>{pr.creator?.name || '-'}</td>
                    <td>{pr.approved_by_user?.name || '-'}</td>
                    <td>{pr.comment || '-'}</td>
                    <td>{new Date(pr.created_at).toLocaleDateString('ru-RU')}</td>
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
              <h2>Создать заявку на материалы</h2>
              <button className="modal-close" onClick={() => setShowModal(false)}>&times;</button>
            </div>
            <div>
              {error && <div className="error">{error}</div>}
              {items.map((item, index) => (
                <div key={index} style={{ marginBottom: '15px', padding: '10px', background: '#f5f5f5', borderRadius: '4px' }}>
                  <div className="form-group">
                    <label>Название материала</label>
                    <input
                      type="text"
                      value={item.name}
                      onChange={(e) => updateItem(index, 'name', e.target.value)}
                      placeholder="Например: Кабель HDMI"
                    />
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                    <div className="form-group">
                      <label>Количество</label>
                      <input
                        type="number"
                        min="1"
                        value={item.quantity}
                        onChange={(e) => updateItem(index, 'quantity', parseInt(e.target.value))}
                      />
                    </div>
                    <div className="form-group">
                      <label>Единица</label>
                      <select
                        value={item.unit}
                        onChange={(e) => updateItem(index, 'unit', e.target.value)}
                      >
                        <option value="pcs">шт</option>
                        <option value="m">м</option>
                        <option value="m2">м2</option>
                        <option value="m3">м3</option>
                        <option value="l">л</option>
                        <option value="kg">кг</option>
                        <option value="box">коробка</option>
                        <option value="pack">упаковка</option>
                        <option value="set">комплект</option>
                      </select>
                    </div>
                  </div>
                  <div className="form-group">
                    <label>Примечание</label>
                    <input
                      type="text"
                      value={item.note}
                      onChange={(e) => updateItem(index, 'note', e.target.value)}
                      placeholder="Дополнительное примечание"
                    />
                  </div>
                </div>
              ))}
              <button type="button" className="btn btn-secondary" onClick={addItem} style={{ marginBottom: '15px' }}>
                Добавить позицию
              </button>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setShowModal(false)}>
                  Отмена
                </button>
                <button type="button" className="btn btn-primary" onClick={handleCreateRequest}>
                  Создать заявку
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default InstallationDetail;
