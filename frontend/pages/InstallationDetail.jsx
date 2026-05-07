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
    return <div className="loading">Р—Р°РіСЂСѓР·РєР°...</div>;
  }

  if (!installation) {
    return <div className="container">РњРѕРЅС‚Р°Р¶ РЅРµ РЅР°Р№РґРµРЅ</div>;
  }

  return (
    <div>
      <header className="header">
        <h1>{installation.title}</h1>
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
            <h3 className="card-title">РРЅС„РѕСЂРјР°С†РёСЏ Рѕ РјРѕРЅС‚Р°Р¶Рµ</h3>
            <Link to="/installations" className="btn btn-secondary">РќР°Р·Р°Рґ Рє РјРѕРЅС‚Р°Р¶Р°Рј</Link>
          </div>
          <p><strong>РќР°Р·РІР°РЅРёРµ:</strong> {installation.title}</p>
          <p><strong>РћРїРёСЃР°РЅРёРµ:</strong> {installation.description || '-'}</p>
          <p><strong>РџСЂРѕРµРєС‚:</strong> {installation.project?.name || '-'}</p>
          <p><strong>РСЃРїРѕР»РЅРёС‚РµР»СЊ:</strong> {installation.assignee?.name || '-'}</p>
          <p><strong>РЎС‚Р°С‚СѓСЃ:</strong> 
            <select
              value={installation.status}
              onChange={(e) => handleStatusChange(e.target.value)}
              className={`status-badge status-${installation.status}`}
              style={{ marginLeft: '10px', border: 'none', cursor: 'pointer' }}
            >
              <option value="new">РќРѕРІС‹Р№</option>
              <option value="planned">Р—Р°РїР»Р°РЅРёСЂРѕРІР°РЅ</option>
              <option value="in_progress">Р’ СЂР°Р±РѕС‚Рµ</option>
              <option value="waiting_materials">РћР¶РёРґР°РµС‚ РјР°С‚РµСЂРёР°Р»РѕРІ</option>
              <option value="done">Р—Р°РІРµСЂС€С‘РЅ</option>
              <option value="postponed">РћС‚Р»РѕР¶РµРЅ</option>
            </select>
          </p>
          <p><strong>Р”Р°С‚Р° РјРѕРЅС‚Р°Р¶Р°:</strong> {installation.scheduled_at ? new Date(installation.scheduled_at).toLocaleString('ru-RU') : '-'}</p>
          <p><strong>РђРґСЂРµСЃ:</strong> {installation.address || '-'}</p>
          <p><strong>РЎРѕР·РґР°РЅ:</strong> {new Date(installation.created_at).toLocaleDateString('ru-RU')}</p>
          
          {canCreateRequest && (
            <button 
              className="btn btn-primary" 
              style={{ marginTop: '15px' }}
              onClick={() => setShowModal(true)}
            >
              РЎРѕР·РґР°С‚СЊ Р·Р°СЏРІРєСѓ РЅР° РјР°С‚РµСЂРёР°Р»С‹
            </button>
          )}
        </div>

        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Р—Р°СЏРІРєРё РЅР° РјР°С‚РµСЂРёР°Р»С‹ ({installation.purchaseRequests?.length || 0})</h3>
          </div>
          {(!installation.purchaseRequests || installation.purchaseRequests.length === 0) ? (
            <p>РќРµС‚ Р·Р°СЏРІРѕРє</p>
          ) : (
            <table className="table">
              <thead>
                <tr>
                  <th>РЎС‚Р°С‚СѓСЃ</th>
                  <th>РЎРѕР·РґР°С‚РµР»СЊ</th>
                  <th>РџРѕРґС‚РІРµСЂРґРёР»</th>
                  <th>РљРѕРјРјРµРЅС‚Р°СЂРёР№</th>
                  <th>Р”Р°С‚Р°</th>
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
              <h2>РЎРѕР·РґР°С‚СЊ Р·Р°СЏРІРєСѓ РЅР° РјР°С‚РµСЂРёР°Р»С‹</h2>
              <button className="modal-close" onClick={() => setShowModal(false)}>&times;</button>
            </div>
            <div>
              {error && <div className="error">{error}</div>}
              {items.map((item, index) => (
                <div key={index} style={{ marginBottom: '15px', padding: '10px', background: '#f5f5f5', borderRadius: '4px' }}>
                  <div className="form-group">
                    <label>РќР°Р·РІР°РЅРёРµ РјР°С‚РµСЂРёР°Р»Р°</label>
                    <input
                      type="text"
                      value={item.name}
                      onChange={(e) => updateItem(index, 'name', e.target.value)}
                      placeholder="РќР°РїСЂРёРјРµСЂ: РљР°Р±РµР»СЊ HDMI"
                    />
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                    <div className="form-group">
                      <label>РљРѕР»РёС‡РµСЃС‚РІРѕ</label>
                      <input
                        type="number"
                        min="1"
                        value={item.quantity}
                        onChange={(e) => updateItem(index, 'quantity', parseInt(e.target.value))}
                      />
                    </div>
                    <div className="form-group">
                      <label>Р•РґРёРЅРёС†Р°</label>
                      <select
                        value={item.unit}
                        onChange={(e) => updateItem(index, 'unit', e.target.value)}
                      >
                        <option value="pcs">С€С‚</option>
                        <option value="m">Рј</option>
                        <option value="m2">Рј2</option>
                        <option value="m3">Рј3</option>
                        <option value="l">Р»</option>
                        <option value="kg">РєРі</option>
                        <option value="box">РєРѕСЂРѕР±РєР°</option>
                        <option value="pack">СѓРїР°РєРѕРІРєР°</option>
                        <option value="set">РєРѕРјРїР»РµРєС‚</option>
                      </select>
                    </div>
                  </div>
                  <div className="form-group">
                    <label>РџСЂРёРјРµС‡Р°РЅРёРµ</label>
                    <input
                      type="text"
                      value={item.note}
                      onChange={(e) => updateItem(index, 'note', e.target.value)}
                      placeholder="Р”РѕРїРѕР»РЅРёС‚РµР»СЊРЅРѕРµ РїСЂРёРјРµС‡Р°РЅРёРµ"
                    />
                  </div>
                </div>
              ))}
              <button type="button" className="btn btn-secondary" onClick={addItem} style={{ marginBottom: '15px' }}>
                Р”РѕР±Р°РІРёС‚СЊ РїРѕР·РёС†РёСЋ
              </button>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setShowModal(false)}>
                  РћС‚РјРµРЅР°
                </button>
                <button type="button" className="btn btn-primary" onClick={handleCreateRequest}>
                  РЎРѕР·РґР°С‚СЊ Р·Р°СЏРІРєСѓ
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
