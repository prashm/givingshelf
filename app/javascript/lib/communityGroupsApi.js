import axios from './axios';

export const fetchGroupByShortName = async (shortName) => {
  const response = await axios.get(`/api/community_groups/by_short_name/${shortName}`, {
    withCredentials: true
  });
  return response.data;
};

export const fetchAllGroups = async () => {
  // Note: This endpoint might need to be created if we want to list all groups
  // For now, we'll use the groups from user memberships
  const response = await axios.get('/api/community_groups', {
    withCredentials: true
  });
  return response.data;
};

