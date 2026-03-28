const API_URL = import.meta.env.VITE_API_URL || '/api';

const getToken = () => localStorage.getItem('token');

const headers = () => {
  const token = getToken();
  return {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {})
  };
};

const handleResponse = async (response) => {
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error || 'An error occurred');
  }
  return data;
};

// Auth API
export const authApi = {
  login: async (email, password) => {
    const response = await fetch(`${API_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });
    return handleResponse(response);
  },

  register: async (email, password, name, role) => {
    const response = await fetch(`${API_URL}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, name, role })
    });
    return handleResponse(response);
  },

  getMe: async () => {
    const response = await fetch(`${API_URL}/auth/me`, {
      headers: headers()
    });
    return handleResponse(response);
  },

  getUsers: async (role) => {
    const params = role ? `?role=${role}` : '';
    const response = await fetch(`${API_URL}/auth/users${params}`, {
      headers: headers()
    });
    return handleResponse(response);
  }
};

// Users Status API
export const usersApi = {
  getStatus: async () => {
    const response = await fetch(`${API_URL}/users/status`, {
      headers: headers()
    });
    return handleResponse(response);
  },

  heartbeat: async () => {
    const response = await fetch(`${API_URL}/users/heartbeat`, {
      method: 'POST',
      headers: headers()
    });
    return handleResponse(response);
  },

  markOffline: async () => {
    const response = await fetch(`${API_URL}/users/offline`, {
      method: 'POST',
      headers: headers()
    });
    return handleResponse(response);
  }
};

// Projects API
export const projectsApi = {
  getAll: async (status) => {
    const params = status ? `?status=${status}` : '';
    const response = await fetch(`${API_URL}/projects${params}`, {
      headers: headers()
    });
    return handleResponse(response);
  },

  getById: async (id) => {
    const response = await fetch(`${API_URL}/projects/${id}`, {
      headers: headers()
    });
    return handleResponse(response);
  },

  create: async (project) => {
    const response = await fetch(`${API_URL}/projects`, {
      method: 'POST',
      headers: headers(),
      body: JSON.stringify(project)
    });
    return handleResponse(response);
  },

  update: async (id, project) => {
    const response = await fetch(`${API_URL}/projects/${id}`, {
      method: 'PUT',
      headers: headers(),
      body: JSON.stringify(project)
    });
    return handleResponse(response);
  },

  delete: async (id) => {
    const response = await fetch(`${API_URL}/projects/${id}`, {
      method: 'DELETE',
      headers: headers()
    });
    return handleResponse(response);
  }
};

// Tasks API
export const tasksApi = {
  getAll: async (filters = {}) => {
    const params = new URLSearchParams(filters).toString();
    const response = await fetch(`${API_URL}/tasks${params ? `?${params}` : ''}`, {
      headers: headers()
    });
    return handleResponse(response);
  },

  getById: async (id) => {
    const response = await fetch(`${API_URL}/tasks/${id}`, {
      headers: headers()
    });
    return handleResponse(response);
  },

  create: async (task) => {
    const response = await fetch(`${API_URL}/tasks`, {
      method: 'POST',
      headers: headers(),
      body: JSON.stringify(task)
    });
    return handleResponse(response);
  },

  update: async (id, task) => {
    const response = await fetch(`${API_URL}/tasks/${id}`, {
      method: 'PUT',
      headers: headers(),
      body: JSON.stringify(task)
    });
    return handleResponse(response);
  },

  delete: async (id) => {
    const response = await fetch(`${API_URL}/tasks/${id}`, {
      method: 'DELETE',
      headers: headers()
    });
    return handleResponse(response);
  }
};

// Installations API
export const installationsApi = {
  getAll: async (filters = {}) => {
    const params = new URLSearchParams(filters).toString();
    const response = await fetch(`${API_URL}/installations${params ? `?${params}` : ''}`, {
      headers: headers()
    });
    return handleResponse(response);
  },

  getById: async (id) => {
    const response = await fetch(`${API_URL}/installations/${id}`, {
      headers: headers()
    });
    return handleResponse(response);
  },

  searchAddresses: async (searchTerm) => {
    const params = searchTerm ? `?q=${encodeURIComponent(searchTerm)}` : '';
    const response = await fetch(`${API_URL}/installations/search-address${params}`, {
      headers: headers()
    });
    return handleResponse(response);
  },

  create: async (installation) => {
    const response = await fetch(`${API_URL}/installations`, {
      method: 'POST',
      headers: headers(),
      body: JSON.stringify(installation)
    });
    return handleResponse(response);
  },

  update: async (id, installation) => {
    const response = await fetch(`${API_URL}/installations/${id}`, {
      method: 'PUT',
      headers: headers(),
      body: JSON.stringify(installation)
    });
    return handleResponse(response);
  },

  delete: async (id) => {
    const response = await fetch(`${API_URL}/installations/${id}`, {
      method: 'DELETE',
      headers: headers()
    });
    return handleResponse(response);
  }
};

// Purchase Requests API
export const purchaseRequestsApi = {
  getAll: async (filters = {}) => {
    const params = new URLSearchParams(filters).toString();
    const response = await fetch(`${API_URL}/purchase-requests${params ? `?${params}` : ''}`, {
      headers: headers()
    });
    return handleResponse(response);
  },

  getById: async (id) => {
    const response = await fetch(`${API_URL}/purchase-requests/${id}`, {
      headers: headers()
    });
    return handleResponse(response);
  },

  create: async (request) => {
    const response = await fetch(`${API_URL}/purchase-requests`, {
      method: 'POST',
      headers: headers(),
      body: JSON.stringify(request)
    });
    return handleResponse(response);
  },

  update: async (id, request) => {
    const response = await fetch(`${API_URL}/purchase-requests/${id}`, {
      method: 'PUT',
      headers: headers(),
      body: JSON.stringify(request)
    });
    return handleResponse(response);
  },

  updateStatus: async (id, status, comment, receipt_address, received_at) => {
    const response = await fetch(`${API_URL}/purchase-requests/${id}/status`, {
      method: 'PUT',
      headers: headers(),
      body: JSON.stringify({ status, comment, receipt_address, received_at })
    });
    return handleResponse(response);
  },

  delete: async (id) => {
    const response = await fetch(`${API_URL}/purchase-requests/${id}`, {
      method: 'DELETE',
      headers: headers()
    });
    return handleResponse(response);
  },

  addItem: async (requestId, item) => {
    const response = await fetch(`${API_URL}/purchase-requests/${requestId}/items`, {
      method: 'POST',
      headers: headers(),
      body: JSON.stringify(item)
    });
    return handleResponse(response);
  },

  updateItem: async (itemId, item) => {
    const response = await fetch(`${API_URL}/purchase-requests/items/${itemId}`, {
      method: 'PUT',
      headers: headers(),
      body: JSON.stringify(item)
    });
    return handleResponse(response);
  },

  deleteItem: async (itemId) => {
    const response = await fetch(`${API_URL}/purchase-requests/items/${itemId}`, {
      method: 'DELETE',
      headers: headers()
    });
    return handleResponse(response);
  }
};

// Materials API
export const materialsApi = {
  getAll: async (filters = {}) => {
    const params = new URLSearchParams(filters).toString();
    const response = await fetch(`${API_URL}/materials${params ? `?${params}` : ''}`, {
      headers: headers()
    });
    return handleResponse(response);
  },

  search: async (searchTerm) => {
    const params = searchTerm ? `?search=${encodeURIComponent(searchTerm)}` : '';
    const response = await fetch(`${API_URL}/materials${params}`, {
      headers: headers()
    });
    return handleResponse(response);
  },

  getCategories: async () => {
    const response = await fetch(`${API_URL}/materials/categories/list`, {
      headers: headers()
    });
    return handleResponse(response);
  }
};
