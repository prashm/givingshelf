import axios from 'axios';
import { resolveSiteGroupShortName } from './groupSubdomain';

// Get CSRF token from meta tag
const getCSRFToken = () => {
  if (typeof document === 'undefined') return null;
  const token = document.querySelector('meta[name="csrf-token"]');
  return token ? token.getAttribute('content') : null;
};

// Configure axios defaults
axios.defaults.withCredentials = true;
axios.defaults.headers.common['Content-Type'] = 'application/json';
axios.defaults.headers.common['Accept'] = 'application/json';

// Add request interceptor to include CSRF token and site group context on each request
axios.interceptors.request.use(
  (config) => {
    const token = getCSRFToken();
    if (token) {
      config.headers['X-CSRF-Token'] = token;
    }

    const siteGroupShortName = resolveSiteGroupShortName();
    if (siteGroupShortName) {
      config.headers['X-Site-Group-Short-Name'] = siteGroupShortName;
    }

    // Ensure withCredentials is always true
    config.withCredentials = true;
    // Ensure proper content type for JSON requests
    if (config.data && typeof config.data === 'object' && !(config.data instanceof FormData)) {
      config.headers['Content-Type'] = 'application/json';
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

export default axios;
