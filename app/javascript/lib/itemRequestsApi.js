import axios from '../lib/axios';

export const fetchItemRequests = async (type) => {
  const response = await axios.get('/api/item_requests', {
    params: { type },
    withCredentials: true,
  });
  return response.data;
};

export const fetchItemRequestDetails = async (id) => {
  const response = await axios.get(`/api/item_requests/${id}`, {
    withCredentials: true,
  });
  return response.data;
};

export const fetchChatMessages = async (itemRequestId) => {
  const response = await axios.get(`/api/item_requests/${itemRequestId}/messages`, {
    withCredentials: true,
  });
  return response.data.messages || [];
};

export const updateItemRequestStatus = async (itemRequestId, actionType) => {
  const response = await axios.patch(`/api/item_requests/${itemRequestId}`, {
    action_type: actionType
  }, {
    withCredentials: true,
  });
  return response.data;
};

export const cancelItemRequest = async (itemRequestId) => {
  const response = await axios.delete(`/api/item_requests/${itemRequestId}`, {
    withCredentials: true,
  });
  return response.data;
};
