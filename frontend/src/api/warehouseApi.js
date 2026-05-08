const API_BASE = '/api/warehouse';

const getAuthHeaders = () => {
  const token = localStorage.getItem('token');
  return {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {})
  };
};

export const warehouseApi = {
  // Get stock by material IDs (comma-separated)
  getStockByIds: async (materialIds) => {
    const response = await fetch(`${API_BASE}?material_ids=${materialIds}`, {
      headers: getAuthHeaders()
    });
    
    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Warehouse API error');
    }
    
    return response.json();
  },
  
  // Get warehouse overview
  getOverview: async (filters = {}) => {
    const params = new URLSearchParams(filters);
    const response = await fetch(`${API_BASE}/overview?${params}`, {
      headers: getAuthHeaders()
    });
    
    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Warehouse overview error');
    }
    
    return response.json();
  },
  
  // Update stock (direct use for testing)
  updateStock: async (materialId, quantityDelta, operation, note, location) => {
    const response = await fetch(`${API_BASE}/${materialId}/stock`, {
      method: 'PUT',
      headers: getAuthHeaders(),
      body: JSON.stringify({ quantity_delta: quantityDelta, operation, note, location })
    });
    
    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Stock update error');
    }
    
    return response.json();
  }
};

