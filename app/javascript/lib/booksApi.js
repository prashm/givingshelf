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

export const fetchWishlistItems = async ({ zipCode = null, radius = null, communityGroupId = null, subGroupId = null, type = null, query = null, ageRange = null, pageParams = null } = {}) => {
  const params = {};
  if (zipCode) params.zip_code = zipCode;
  if (radius) params.radius = radius;
  if (communityGroupId) params.community_group_id = communityGroupId;
  if (subGroupId) params.sub_group_id = subGroupId;
  if (type) params.type = type;
  if (query) params.query = query;
  if (ageRange) params.age_range = ageRange;
  if (pageParams) {
    Object.assign(params, pageParams);
  } else {
    params["page[size]"] = 6;
  }
  const response = await axios.get('/api/items/wishlist', {
    params,
    withCredentials: true,
  });

  const data = response.data || {};
  const items = Array.isArray(data.data) ? data.data : [];
  const meta = data.meta || {};
  const links = data.links || {};
  const total = meta.page?.total || meta.total || 0;

  return {
    items,
    paginationMeta: {
      total,
      hasMore: !!links.next,
      nextPageUrl: links.next || null
    }
  };
};

