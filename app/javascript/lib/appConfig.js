const readMeta = (name) => {
  if (typeof document === 'undefined') return '';
  return document.querySelector(`meta[name="${name}"]`)?.getAttribute('content') || '';
};

export const getApplicationDomain = () => readMeta('application-domain');
export const getApplicationProtocol = () => readMeta('application-protocol') || 'https';
export const getApplicationPort = () => readMeta('application-port');
export const getApplicationBaseUrl = () => readMeta('application-base-url');

/** Navigate to the configured apex site (e.g. lvh.me:3000 / givingshelf.net), leaving any group subdomain. */
export const navigateToApexHome = () => {
  const base = getApplicationBaseUrl();
  window.location.href = base || '/';
};

export const applicationEmail = (localPart) => {
  const domain = getApplicationDomain();
  return domain ? `${localPart}@${domain}` : localPart;
};
