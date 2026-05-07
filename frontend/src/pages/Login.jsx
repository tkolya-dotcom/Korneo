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
    setError('');
    setLoading(true);

    try {
      await login(email, password);
      navigate('/');
    } catch (err) {
      setError(err.message || 'Login failed. Please check your credentials.');
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
      setError('Password must be at least 6 characters.');
      setLoading(false);
      return;
    }

    try {
      await register(email, password, name, role);
      setSuccess('Registration successful. Redirecting...');
      setTimeout(() => navigate('/'), 1200);
    } catch (err) {
      setError(err.message || 'Registration failed.');
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
        <h2>{isRegisterMode ? 'Register' : 'Sign In'}</h2>

        {error && <div className="error">{error}</div>}
        {success && <div className="success">{success}</div>}

        {isRegisterMode && (
          <div className="form-group">
            <label>Name</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              placeholder="Enter your name"
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
            placeholder="Enter email"
          />
        </div>

        <div className="form-group">
          <label>Password</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            placeholder={isRegisterMode ? 'Minimum 6 characters' : 'Enter password'}
            minLength={isRegisterMode ? 6 : undefined}
          />
        </div>

        {isRegisterMode && (
          <div className="form-group">
            <label>Role</label>
            <select value={role} onChange={(e) => setRole(e.target.value)} required>
              <option value="worker">Worker</option>
              <option value="manager">Manager</option>
            </select>
          </div>
        )}

        <button type="submit" className="btn btn-primary" disabled={loading} style={{ width: '100%' }}>
          {loading ? (isRegisterMode ? 'Registering...' : 'Signing in...') : (isRegisterMode ? 'Create account' : 'Sign in')}
        </button>

        <div style={{ marginTop: '20px', textAlign: 'center' }}>
          <button
            type="button"
            className="btn btn-link"
            onClick={toggleMode}
            style={{ background: 'none', border: 'none', color: '#1976d2', cursor: 'pointer', textDecoration: 'underline' }}
          >
            {isRegisterMode ? 'Already have an account? Sign in' : 'No account? Register'}
          </button>
        </div>
      </form>
    </div>
  );
};

export default Login;
