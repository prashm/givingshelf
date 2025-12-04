import axios from './axios';

export const fetchCommunityStats = async (zipCode) => {
  const response = await axios.get('/api/books/stats', {
    params: zipCode ? { zip_code: zipCode } : {},
    withCredentials: true,
  });
  return response.data;
};

