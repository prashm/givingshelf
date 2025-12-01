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


