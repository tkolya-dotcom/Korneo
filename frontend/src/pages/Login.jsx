import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const humanizeAuthError = (message = '') => {
  const m = String(message).toLowerCase();
  if (m.includes('invalid login credentials')) return 'Неверный email или пароль.';
  if (m.includes('email not confirmed')) return 'Email не подтверждён. Подтвердите почту и попробуйте снова.';
  if (m.includes('too many requests')) return 'Слишком много попыток входа. Подождите немного.';
  if (m.includes('network')) return 'Проблема сети. Проверьте интернет и попробуйте снова.';
  return message || 'Ошибка авторизации.';
};

const Login = () => {
  const [isRegisterMode, setIsRegisterMode] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [role, setRole] = useState('worker');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState('');
  const { login, register } = useAuth();
  const navigate = useNavigate();

  const handleLoginSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      await login(email, password);
      navigate('/');
    } catch (err) {
      setError(humanizeAuthError(err?.message));
    } finally {
      setLoading(false);
    }
  };

  const handleRegisterSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    setLoading(true);

    if (password.length < 6) {
      setError('Пароль должен быть не менее 6 символов.');
      setLoading(false);
      return;
    }

    try {
      await register(email, password, name, role);
      setSuccess('Регистрация успешна. Перенаправление...');
      setTimeout(() => navigate('/'), 1200);
    } catch (err) {
      setError(humanizeAuthError(err?.message));
    } finally {
      setLoading(false);
    }
  };

  const toggleMode = () => {
    setIsRegisterMode(!isRegisterMode);
    setError('');
    setSuccess('');
    setEmail('');
    setPassword('');
    setName('');
    setRole('worker');
  };

  return (
    <div className="login-container">
      <form className="login-form" onSubmit={isRegisterMode ? handleRegisterSubmit : handleLoginSubmit}>
        <h2>{isRegisterMode ? 'Регистрация' : 'Вход в систему'}</h2>

        {error && <div className="error">{error}</div>}
        {success && <div className="success">{success}</div>}

        {isRegisterMode && (
          <div className="form-group">
            <label>Имя</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              placeholder="Введите ваше имя"
            />
          </div>
        )}

        <div className="form-group">
          <label>Email</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            placeholder="Введите email"
          />
        </div>

        <div className="form-group">
          <label>Пароль</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            placeholder={isRegisterMode ? 'Минимум 6 символов' : 'Введите пароль'}
            minLength={isRegisterMode ? 6 : undefined}
          />
        </div>

        {isRegisterMode && (
          <div className="form-group">
            <label>Роль</label>
            <select value={role} onChange={(e) => setRole(e.target.value)} required>
              <option value="worker">Исполнитель</option>
              <option value="manager">Руководитель</option>
            </select>
          </div>
        )}

        <button type="submit" className="btn btn-primary" disabled={loading} style={{ width: '100%' }}>
          {loading ? (isRegisterMode ? 'Регистрация...' : 'Вход...') : (isRegisterMode ? 'Зарегистрироваться' : 'Войти')}
        </button>

        <div style={{ marginTop: '20px', textAlign: 'center' }}>
          <button
            type="button"
            className="btn btn-link"
            onClick={toggleMode}
            style={{ background: 'none', border: 'none', color: '#1976d2', cursor: 'pointer', textDecoration: 'underline' }}
          >
            {isRegisterMode ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Зарегистрироваться'}
          </button>
        </div>
      </form>
    </div>
  );
};

export default Login;
