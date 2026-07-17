import React, { createContext, useContext, useEffect, useState } from 'react';
import axios from '../lib/axios';
import { useAuth } from './AuthContext';
import { resolveSiteGroupShortName } from '../lib/groupSubdomain';

const SiteGroupContext = createContext({
  siteGroup: null,
  rules: {
    email_domain_required: null,
    restrict_join_other_groups: false,
  },
  urlMode: 'none',
  loading: true,
  refreshSiteContext: async () => {},
});

export const useSiteGroup = () => useContext(SiteGroupContext);

export const SiteGroupProvider = ({ children }) => {
  const { currentUser } = useAuth();
  const [siteGroup, setSiteGroup] = useState(null);
  const [rules, setRules] = useState({
    email_domain_required: null,
    restrict_join_other_groups: false,
  });
  const [urlMode, setUrlMode] = useState('none');
  const [loading, setLoading] = useState(true);

  const refreshSiteContext = async () => {
    const shortName = resolveSiteGroupShortName();
    try {
      const res = await axios.get('/api/site_context', {
        withCredentials: true,
        headers: shortName ? { 'X-Site-Group-Short-Name': shortName } : {},
      });
      setSiteGroup(res.data?.host_group || null);
      setRules({
        email_domain_required: res.data?.rules?.email_domain_required || null,
        restrict_join_other_groups: Boolean(res.data?.rules?.restrict_join_other_groups),
      });
      setUrlMode(res.data?.url_mode || 'none');
    } catch (e) {
      setSiteGroup(null);
      setRules({
        email_domain_required: null,
        restrict_join_other_groups: false,
      });
      setUrlMode('none');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    refreshSiteContext();
  }, [currentUser?.id]);

  return (
    <SiteGroupContext.Provider
      value={{
        siteGroup,
        rules,
        urlMode,
        loading,
        refreshSiteContext,
      }}
    >
      {children}
    </SiteGroupContext.Provider>
  );
};

export default SiteGroupContext;
