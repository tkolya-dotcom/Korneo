import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { tasksApi, purchaseRequestsApi } from '../api';

const TaskDetail = () => {
  const { id } = useParams();
  const { user, isManager } = useAuth();
  const [task, setTask] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [items, setItems] = useState([{ name: '', quantity: 1, unit: 'pcs', note: '' }]);

  useEffect(() => {
    loadData();
  }, [id]);

  const loadData = async () => {
    try {
      const data = await tasksApi.getById(id);
      setTask(data.task);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleStatusChange = async (newStatus) => {
    try {
      await tasksApi.update(id, { status: newStatus });
      loadData();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleCreateRequest = async () => {
    try {
      await purchaseRequestsApi.create({
        task_id: id,
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

  const canCreateRequest = task && (
    task.assignee_id === user.id || 
    isManager
  );

  if (loading) {
    return <div className="loading">Загрузка...</div>;
  }

  if (!task) {
    return <div className="container">Задача не найдена</div>;
  }

  return (
    <div>
      <header className="header">
        <h1>{task.title}</h1>
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
            <h3 className="card-title">Информация о задаче</h3>
            <Link to="/tasks" className="btn btn-secondary">Назад к задачам</Link>
          </div>
          <p><strong>Название:</strong> {task.title}</p>
          <p><strong>Описание:</strong> {task.description || '-'}</p>
          <p><strong>Проект:</strong> {task.project?.name || '-'}</p>
          <p><strong>Исполнитель:</strong> {task.assignee?.name || '-'}</p>
          <p><strong>Статус:</strong> 
            <select
              value={task.status}
              onChange={(e) => handleStatusChange(e.target.value)}
              className={`status-badge status-${task.status}`}
              style={{ marginLeft: '10px', border: 'none', cursor: 'pointer' }}
            >
              <option value="new">Новая</option>
              <option value="planned">Запланирована</option>
              <option value="in_progress">В работе</option>
              <option value="waiting_materials">Ожидает материалов</option>
              <option value="done">Выполнена</option>
              <option value="postponed">Отложена</option>
            </select>
          </p>
          <p><strong>Срок:</strong> {task.due_date ? new Date(task.due_date).toLocaleDateString('ru-RU') : '-'}</p>
          <p><strong>Создана:</strong> {new Date(task.created_at).toLocaleDateString('ru-RU')}</p>
          
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
            <h3 className="card-title">Заявки на материалы ({task.purchaseRequests?.length || 0})</h3>
          </div>
          {(!task.purchaseRequests || task.purchaseRequests.length === 0) ? (
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
                {task.purchaseRequests.map(pr => (
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

export default TaskDetail;
