import axios from './axios';

export const fetchCommunityStats = async (zipCode, radius = null, communityGroupId = null, subGroupId = null, type = null) => {
  const params = {};
  if (zipCode) params.zip_code = zipCode;
  if (radius) params.radius = radius;
  if (communityGroupId) params.community_group_id = communityGroupId;
  if (subGroupId) params.sub_group_id = subGroupId;
  if (type) params.type = type;
  const response = await axios.get('/api/items/stats', {
    params,
    withCredentials: true,
  });
  return response.data;
};

