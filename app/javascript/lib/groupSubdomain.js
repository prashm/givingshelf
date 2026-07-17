import {
  getApplicationDomain,
  getApplicationPort,
  getApplicationProtocol,
} from './appConfig';

const RESERVED = ['www', 'api', 'admin', 'mail', 'smtp', 'staging', 'dev', 'test'];

/** Apex/loopback hosts (before /g/ redirect). Group subdomains like bvsd.lvh.me are not local apex. */
export const isLocalDevHost = (hostname = typeof window !== 'undefined' ? window.location.hostname : '') => {
  const host = (hostname || '').toLowerCase();
  const configuredDomain = getApplicationDomain().toLowerCase();
  return (
    host === 'localhost' ||
    host === '127.0.0.1' ||
    host === '[::1]' ||
    (configuredDomain && host === configuredDomain)
  );
};

/**
 * Parse group short_name from a configured application-domain hostname
 * (e.g. bvsd.lvh.me or acme.givingshelf.net).
 */
export const getHostGroupShortName = (hostname = typeof window !== 'undefined' ? window.location.hostname : '') => {
  const host = (hostname || '').toLowerCase();
  if (!host) return null;
  const appDomain = getApplicationDomain().toLowerCase();
  if (!appDomain) return null;
  const hostSuffix = `.${appDomain}`;
  if (!host.endsWith(hostSuffix)) return null;
  if (host === appDomain || host === `www.${appDomain}`) return null;

  const shortName = host.slice(0, -hostSuffix.length);
  if (!shortName || shortName.includes('.') || RESERVED.includes(shortName)) return null;
  return shortName;
};

/** True when the current host is already a group subdomain (e.g. bvsd.lvh.me). */
export const useSubdomainUrls = (hostname = typeof window !== 'undefined' ? window.location.hostname : '') => {
  return Boolean(getHostGroupShortName(hostname));
};

/**
 * Parse /g/:short_name from a pathname.
 */
export const getPathGroupShortName = (pathname = typeof window !== 'undefined' ? window.location.pathname : '') => {
  const match = (pathname || '').match(/^\/g\/([^/]+)/);
  if (!match) return null;
  const shortName = match[1];
  if (RESERVED.includes(shortName)) return null;
  return shortName;
};

/**
 * Single entry point for site group short name:
 * 1. Host subdomain
 * 2. /g/:short_name path (apex localhost before redirect)
 * 3. history.state.groupShortName
 */
export const resolveSiteGroupShortName = () => {
  if (typeof window === 'undefined') return null;

  const fromHost = getHostGroupShortName();
  if (fromHost) return fromHost;

  const fromPath = getPathGroupShortName();
  if (fromPath) return fromPath;

  const state = window.history.state;
  if (state?.groupShortName) return state.groupShortName;

  return null;
};

const hostWithPort = (hostname) => {
  const port = getApplicationPort();
  return port ? `${hostname}:${port}` : hostname;
};

/**
 * Absolute group URL on the configured application domain (includes port in development).
 */
export const groupPublicPathOrHost = (shortName, path = '/') => {
  if (!shortName) return path;
  const normalized = path === '/' || path === '' ? '' : (path.startsWith('/') ? path : `/${path}`);
  const host = hostWithPort(`${shortName}.${getApplicationDomain()}`);
  return `${getApplicationProtocol()}://${host}${normalized || '/'}`;
};

export { RESERVED };
