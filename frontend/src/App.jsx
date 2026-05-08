import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { useAuth } from './context/AuthContext';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Projects from './pages/Projects';
import Tasks from './pages/Tasks';
import Installations from './pages/Installations';
import PurchaseRequests from './pages/PurchaseRequests';
import ProjectDetail from './pages/ProjectDetail';
import TaskDetail from './pages/TaskDetail';
import InstallationDetail from './pages/InstallationDetail';
import Archive from './pages/Archive';

function PrivateRoute({ children }) {
  const { user, loading } = useAuth();
  
  if (loading) {
    return <div className="loading">Загрузка...</div>;
  }
  
  return user ? children : <Navigate to="/login" />;
}

function App() {
  return (
    <div className="app">
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/" element={
          <PrivateRoute>
            <Dashboard />
          </PrivateRoute>
        } />
        <Route path="/projects" element={
          <PrivateRoute>
            <Projects />
          </PrivateRoute>
        } />
        <Route path="/projects/:id" element={
          <PrivateRoute>
            <ProjectDetail />
          </PrivateRoute>
        } />
        <Route path="/tasks" element={
          <PrivateRoute>
            <Tasks />
          </PrivateRoute>
        } />
        <Route path="/tasks/:id" element={
          <PrivateRoute>
            <TaskDetail />
          </PrivateRoute>
        } />
        <Route path="/installations" element={
          <PrivateRoute>
            <Installations />
          </PrivateRoute>
        } />
        <Route path="/installations/:id" element={
          <PrivateRoute>
            <InstallationDetail />
          </PrivateRoute>
        } />
        <Route path="/purchase-requests" element={
          <PrivateRoute>
            <PurchaseRequests />
          </PrivateRoute>
        } />
        <Route path="/archive" element={
          <PrivateRoute>
            <Archive />
          </PrivateRoute>
        } />
      </Routes>
    </div>
  );
}

export default App;
