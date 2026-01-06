import axios from './axios';

export const fetchCommunityStats = async (zipCode, radius = null) => {
  const params = {};
  if (zipCode) {
    params.zip_code = zipCode;
  }
  if (radius) {
    params.radius = radius;
  }
  const response = await axios.get('/api/books/stats', {
    params,
    withCredentials: true,
  });
  return response.data;
};

