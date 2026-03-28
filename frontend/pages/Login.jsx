import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

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
    e.stopPropagation();
    setError('');
    setLoading(true);

    console.log('Login button clicked, email:', email);
    console.log('API URL:', import.meta.env.VITE_API_URL || '/api');

    try {
      const result = await login(email, password);
      console.log('Login successful:', result);
      navigate('/');
    } catch (err) {
      console.error('Login error:', err);
      setError(err.message || 'Ошибка входа. Проверьте консоль для деталей.');
    } finally {
      setLoading(false);
    }
  };

  const handleRegisterSubmit = async (e) => {
    e.preventDefault();
    e.stopPropagation();
    setError('');
    setSuccess('');
    setLoading(true);

    console.log('Register button clicked, email:', email, 'name:', name, 'role:', role);

    // Validate password length
    if (password.length < 6) {
      setError('Пароль должен быть не менее 6 символов');
      setLoading(false);
      return;
    }

    try {
      const result = await register(email, password, name, role);
      console.log('Registration successful:', result);
      setSuccess('Регистрация успешна! Перенаправление...');
      setTimeout(() => {
        navigate('/');
      }, 1500);
    } catch (err) {
      console.error('Registration error:', err);
      setError(err.message || 'Ошибка регистрации. Проверьте консоль для деталей.');
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
          {loading 
            ? (isRegisterMode ? 'Регистрация...' : 'Вход...') 
            : (isRegisterMode ? 'Зарегистрироваться' : 'Войти')
          }
        </button>

        <div style={{ marginTop: '20px', textAlign: 'center' }}>
          <button 
            type="button" 
            className="btn btn-link" 
            onClick={toggleMode}
            style={{ background: 'none', border: 'none', color: '#1976d2', cursor: 'pointer', textDecoration: 'underline' }}
          >
            {isRegisterMode 
              ? 'Уже есть аккаунт? Войти' 
              : 'Нет аккаунта? Зарегистрироваться'
            }
          </button>
        </div>

        {!isRegisterMode && (
          <div style={{ marginTop: '20px', textAlign: 'center', fontSize: '14px', color: '#757575' }}>
            <p>Тестовые аккаунты:</p>
            <p>Руководитель: manager@test.com</p>
            <p>Исполнитель: worker@test.com</p>
          </div>
        )}
      </form>
    </div>
  );
};

export default Login;
