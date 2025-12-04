import axios from '../lib/axios';

export const fetchBookRequests = async (type) => {
  const response = await axios.get('/api/book_requests', {
    params: { type },
    withCredentials: true,
  });
  return response.data;
};

export const fetchBookRequestDetails = async (id) => {
  const response = await axios.get(`/api/book_requests/${id}`, {
    withCredentials: true,
  });
  return response.data;
};

export const fetchChatMessages = async (bookRequestId) => {
  const response = await axios.get(`/api/book_requests/${bookRequestId}/messages`, {
    withCredentials: true,
  });
  return response.data.messages || [];
};

export const updateBookRequestStatus = async (bookRequestId, actionType) => {
  const response = await axios.patch(`/api/book_requests/${bookRequestId}`, {
    action_type: actionType
  }, {
    withCredentials: true,
  });
  return response.data;
};

