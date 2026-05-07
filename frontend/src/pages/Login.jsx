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
      setError(err.message || 'РћС€РёР±РєР° РІС…РѕРґР°. РџСЂРѕРІРµСЂСЊС‚Рµ РєРѕРЅСЃРѕР»СЊ РґР»СЏ РґРµС‚Р°Р»РµР№.');
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

    if (password.length < 6) {
      setError('РџР°СЂРѕР»СЊ РґРѕР»Р¶РµРЅ Р±С‹С‚СЊ РЅРµ РјРµРЅРµРµ 6 СЃРёРјРІРѕР»РѕРІ');
      setLoading(false);
      return;
    }

    try {
      const result = await register(email, password, name, role);
      console.log('Registration successful:', result);
      setSuccess('Р РµРіРёСЃС‚СЂР°С†РёСЏ СѓСЃРїРµС€РЅР°! РџРµСЂРµРЅР°РїСЂР°РІР»РµРЅРёРµ...');
      setTimeout(() => {
        navigate('/');
      }, 1500);
    } catch (err) {
      console.error('Registration error:', err);
      setError(err.message || 'РћС€РёР±РєР° СЂРµРіРёСЃС‚СЂР°С†РёРё. РџСЂРѕРІРµСЂСЊС‚Рµ РєРѕРЅСЃРѕР»СЊ РґР»СЏ РґРµС‚Р°Р»РµР№.');
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
        <h2>{isRegisterMode ? 'Р РµРіРёСЃС‚СЂР°С†РёСЏ' : 'Р’С…РѕРґ РІ СЃРёСЃС‚РµРјСѓ'}</h2>
        
        {error && <div className="error">{error}</div>}
        {success && <div className="success">{success}</div>}

        {isRegisterMode && (
          <div className="form-group">
            <label>РРјСЏ</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              placeholder="Р’РІРµРґРёС‚Рµ РІР°С€Рµ РёРјСЏ"
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
            placeholder="Р’РІРµРґРёС‚Рµ email"
          />
        </div>

        <div className="form-group">
          <label>РџР°СЂРѕР»СЊ</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            placeholder={isRegisterMode ? 'РњРёРЅРёРјСѓРј 6 СЃРёРјРІРѕР»РѕРІ' : 'Р’РІРµРґРёС‚Рµ РїР°СЂРѕР»СЊ'}
            minLength={isRegisterMode ? 6 : undefined}
          />
        </div>

        {isRegisterMode && (
          <div className="form-group">
            <label>Р РѕР»СЊ</label>
            <select value={role} onChange={(e) => setRole(e.target.value)} required>
              <option value="worker">РСЃРїРѕР»РЅРёС‚РµР»СЊ</option>
              <option value="manager">Р СѓРєРѕРІРѕРґРёС‚РµР»СЊ</option>
            </select>
          </div>
        )}

        <button type="submit" className="btn btn-primary" disabled={loading} style={{ width: '100%' }}>
          {loading 
            ? (isRegisterMode ? 'Р РµРіРёСЃС‚СЂР°С†РёСЏ...' : 'Р’С…РѕРґ...') 
            : (isRegisterMode ? 'Р—Р°СЂРµРіРёСЃС‚СЂРёСЂРѕРІР°С‚СЊСЃСЏ' : 'Р’РѕР№С‚Рё')
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
              ? 'РЈР¶Рµ РµСЃС‚СЊ Р°РєРєР°СѓРЅС‚? Р’РѕР№С‚Рё' 
              : 'РќРµС‚ Р°РєРєР°СѓРЅС‚Р°? Р—Р°СЂРµРіРёСЃС‚СЂРёСЂРѕРІР°С‚СЊСЃСЏ'
            }
          </button>
        </div>

        {!isRegisterMode && (
          <div style={{ marginTop: '20px', textAlign: 'center', fontSize: '14px', color: '#757575' }}>
            <p>РўРµСЃС‚РѕРІС‹Рµ Р°РєРєР°СѓРЅС‚С‹:</p>
            <p>Р СѓРєРѕРІРѕРґРёС‚РµР»СЊ: manager@test.com</p>
            <p>РСЃРїРѕР»РЅРёС‚РµР»СЊ: worker@test.com</p>
          </div>
        )}
      </form>
    </div>
  );
};

export default Login;
