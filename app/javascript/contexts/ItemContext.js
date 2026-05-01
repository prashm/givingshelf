import React, { createContext, useContext, useState, useCallback, useMemo } from 'react';
import axios from '../lib/axios';
import * as Constants from '../lib/constants';

const ItemContext = createContext();

export const useItems = () => {
  const context = useContext(ItemContext);
  if (!context) {
    throw new Error('useItems must be used within an ItemProvider');
  }
  return context;
};

export const ItemProvider = ({ children, itemType = Constants.ITEM_TYPE_BOOK }) => {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [paginationMeta, setPaginationMeta] = useState({
    total: 0,
    hasMore: false,
    nextPageUrl: null
  });
  const [currentEndpoint, setCurrentEndpoint] = useState('/api/items');

  const toStableFile = useCallback(async (file, fallbackName = 'upload.jpg') => {
    if (!file) return null;
    if (file instanceof Blob) {
      const name = (file instanceof File && file.name) || file.name || fallbackName;
      const type = file.type || 'application/octet-stream';
      const bytes = await file.arrayBuffer();
      return new File([bytes], name, { type, lastModified: Date.now() });
    }
    if (typeof file === 'string') return file;
    return null;
  }, []);

  const validateImageSize = useCallback((itemData) => {
    const MAX_TOTAL_SIZE = 20 * 1024 * 1024;
    let totalSize = 0;
    if (itemData.user_images && Array.isArray(itemData.user_images)) {
      for (const img of itemData.user_images) {
        if (img instanceof File || img instanceof Blob) totalSize += img.size;
      }
    }
    if (totalSize > MAX_TOTAL_SIZE) {
      const totalMB = (totalSize / (1024 * 1024)).toFixed(1);
      return { valid: false, error: `Total image size (${totalMB}MB) exceeds 20MB limit. Please reduce image sizes or remove some photos.` };
    }
    return { valid: true };
  }, []);

  const buildItemFormData = useCallback(async (itemData, options = {}) => {
    const { includeTextFields = false, textFields = [], paramPrefix = 'item' } = options;
    const formData = new FormData();
    if (includeTextFields) {
      textFields.forEach(key => {
        let value = '';
        if (itemData.hasOwnProperty(key)) {
          value = itemData[key] === null || itemData[key] === undefined ? '' : String(itemData[key]);
        }
        formData.append(`${paramPrefix}[${key}]`, value);
      });
    }
    for (const key of Object.keys(itemData)) {
      if (includeTextFields && textFields.includes(key)) continue;
      if (key === 'user_images' && Array.isArray(itemData[key])) {
        for (let i = 0; i < itemData[key].length; i++) {
          const stable = await toStableFile(itemData[key][i], `user-image-${i + 1}.jpg`);
          if (stable instanceof File) formData.append(`${paramPrefix}[user_images][]`, stable);
        }
      } else if (key === 'community_group_ids' && Array.isArray(itemData[key])) {
        itemData[key].forEach((id) => formData.append(`${paramPrefix}[community_group_ids][]`, id));
      } else if (key === 'remove_user_image_indices' && Array.isArray(itemData[key])) {
        itemData[key].forEach((index) => formData.append(`${paramPrefix}[remove_user_image_indices][]`, index));
      } else if (key === 'cover_image') {
        const stable = await toStableFile(itemData[key], 'cover-image.jpg');
        if (stable instanceof File) formData.append(`${paramPrefix}[cover_image]`, stable);
        else if (typeof stable === 'string') formData.append(`${paramPrefix}[cover_image]`, stable);
      } else if (itemData[key] !== null && itemData[key] !== undefined) {
        formData.append(`${paramPrefix}[${key}]`, itemData[key]);
      }
    }
    return formData;
  }, [toStableFile]);

  const fetchItems = useCallback(async (params = {}, append = false) => {
    setLoading(true);
    setError(null);
    try {
      const paginationParams = { 'page[size]': 6, type: itemType, ...params };
      const endpoint = '/api/items';
      setCurrentEndpoint(endpoint);
      const response = await axios.get(endpoint, { params: paginationParams, withCredentials: true });
      if (response.data && response.data.data) {
        const itemsData = response.data.data;
        const meta = response.data.meta || {};
        const links = response.data.links || {};
        const total = meta.page?.total || meta.total || 0;
        if (append) setItems(prev => [...prev, ...itemsData]);
        else setItems(itemsData);
        setPaginationMeta({ total, hasMore: !!links.next, nextPageUrl: links.next || null });
      } else {
        const itemsData = Array.isArray(response.data) ? response.data : [];
        if (append) setItems(prev => [...prev, ...itemsData]);
        else setItems(itemsData);
        setPaginationMeta({ total: itemsData.length, hasMore: false, nextPageUrl: null });
      }
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to fetch items');
    } finally {
      setLoading(false);
    }
  }, [itemType]);

  const loadMoreItems = useCallback(async () => {
    if (!paginationMeta.nextPageUrl || loading) return;
    setLoading(true);
    setError(null);
    try {
      let url = paginationMeta.nextPageUrl;
      if (url.startsWith('/')) url = `${window.location.origin}${url}`;
      else if (!url.startsWith('http')) url = `${window.location.origin}/${url}`;
      const urlObj = new URL(url);
      const params = {};
      urlObj.searchParams.forEach((value, key) => { params[key] = value; });
      const response = await axios.get(currentEndpoint, { params, withCredentials: true });
      if (response.data && response.data.data) {
        const itemsData = response.data.data;
        const meta = response.data.meta || {};
        const links = response.data.links || {};
        const total = meta.page?.total || meta.total || paginationMeta.total;
        setItems(prev => [...prev, ...itemsData]);
        setPaginationMeta({ total, hasMore: !!links.next, nextPageUrl: links.next || null });
      }
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to load more items');
    } finally {
      setLoading(false);
    }
  }, [paginationMeta, loading, currentEndpoint]);

  const searchItems = useCallback(async (query, zipCode, append = false, radius = null, communityGroupId = null, subGroupId = null) => {
    setLoading(true);
    setError(null);
    try {
      const normalizedQuery = (query || '').trim();
      const paginationParams = {
        'page[size]': 6,
        query: normalizedQuery,
        zip_code: zipCode,
        type: itemType
      };
      if (radius) paginationParams.radius = radius;
      if (communityGroupId) paginationParams.community_group_id = communityGroupId;
      if (subGroupId) paginationParams.sub_group_id = subGroupId;
      const endpoint = '/api/items/search';
      setCurrentEndpoint(endpoint);
      const response = await axios.get(endpoint, { params: paginationParams, withCredentials: true });
      if (response.data && response.data.data) {
        const itemsData = response.data.data;
        const meta = response.data.meta || {};
        const links = response.data.links || {};
        const total = meta.page?.total || meta.total || 0;
        if (append) setItems(prev => [...prev, ...itemsData]);
        else setItems(itemsData);
        setPaginationMeta({ total, hasMore: !!links.next, nextPageUrl: links.next || null });
      } else {
        const itemsData = Array.isArray(response.data) ? response.data : [];
        if (append) setItems(prev => [...prev, ...itemsData]);
        else setItems(itemsData);
        setPaginationMeta({ total: itemsData.length, hasMore: false, nextPageUrl: null });
      }
    } catch (err) {
      setError(err.response?.data?.error || 'Search failed');
    } finally {
      setLoading(false);
    }
  }, [itemType]);

  const getItem = useCallback(async (id) => {
    setLoading(true);
    setError(null);
    try {
      const response = await axios.get(`/api/items/${id}`, { params: { type: itemType }, withCredentials: true });
      return response.data;
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to fetch item');
      return null;
    } finally {
      setLoading(false);
    }
  }, [itemType]);

  const createItem = useCallback(async (itemData) => {
    setLoading(true);
    setError(null);
    try {
      const validation = validateImageSize(itemData);
      if (!validation.valid) {
        setError(validation.error);
        setLoading(false);
        return { success: false, error: validation.error };
      }
      const formData = await buildItemFormData({ ...itemData, type: itemType });
      const response = await axios.post('/api/items', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
        withCredentials: true
      });
      setItems(prev => [response.data, ...prev]);
      return { success: true, item: response.data };
    } catch (err) {
      const errorMsg = err.response?.data?.errors?.join(', ') || 'Failed to create item';
      setError(errorMsg);
      return { success: false, error: errorMsg };
    } finally {
      setLoading(false);
    }
  }, [itemType, validateImageSize, buildItemFormData]);

  const updateItem = useCallback(async (itemId, itemData) => {
    setLoading(true);
    setError(null);
    try {
      const validation = validateImageSize(itemData);
      if (!validation.valid) {
        setError(validation.error);
        setLoading(false);
        return { success: false, error: validation.error };
      }
      const textFields = ['personal_note', 'pickup_method', 'pickup_address'];
      const formData = await buildItemFormData(itemData, { includeTextFields: true, textFields });
      const response = await axios.patch(`/api/items/${itemId}`, formData, {
        params: { type: itemType },
        headers: { 'Content-Type': 'multipart/form-data' },
        withCredentials: true
      });
      setItems(prev => prev.map(item => item.id === itemId ? response.data : item));
      return { success: true, item: response.data };
    } catch (err) {
      const errorMsg = err.response?.data?.errors?.join(', ') || 'Failed to update item';
      setError(errorMsg);
      return { success: false, error: errorMsg };
    } finally {
      setLoading(false);
    }
  }, [itemType, validateImageSize, buildItemFormData]);

  const deleteItem = useCallback(async (itemId) => {
    setLoading(true);
    setError(null);
    try {
      await axios.delete(`/api/items/${itemId}`, { params: { type: itemType }, withCredentials: true });
      setItems(prev => prev.filter(item => item.id !== itemId));
      return { success: true };
    } catch (err) {
      const errorMsg = err.response?.data?.error || 'Failed to delete item';
      setError(errorMsg);
      return { success: false, error: errorMsg };
    } finally {
      setLoading(false);
    }
  }, [itemType]);

  const requestItem = useCallback(async (itemId, message) => {
    setLoading(true);
    setError(null);
    try {
      const response = await axios.post('/api/item_requests', { item_id: itemId, message }, { withCredentials: true });
      setItems(prev => prev.map(item => item.id === itemId ? { ...item, can_request: false } : item));
      return { success: true, request: response.data };
    } catch (err) {
      const errorMsg = err.response?.data?.error || 'Failed to request item';
      setError(errorMsg);
      return { success: false, error: errorMsg };
    } finally {
      setLoading(false);
    }
  }, []);

  const value = useMemo(() => ({
    items,
    loading,
    error,
    paginationMeta,
    itemType,
    fetchItems,
    loadMoreItems,
    searchItems,
    getItem,
    createItem,
    updateItem,
    deleteItem,
    requestItem,
    buildItemFormData,
    validateImageSize
  }), [items, loading, error, paginationMeta, itemType, fetchItems, loadMoreItems, searchItems, getItem, createItem, updateItem, deleteItem, requestItem, buildItemFormData, validateImageSize]);

  return (
    <ItemContext.Provider value={value}>
      {children}
    </ItemContext.Provider>
  );
};
