export const BROWSE_ZIP_COOKIE_NAME = 'gs_browse_zip';
const ZIP_CODE_REGEX = /^\d{5}$/;
const BROWSE_ZIP_COOKIE_MAX_AGE_SECONDS = 60 * 60 * 24 * 365;

export const normalizeBrowseZip = (value) => {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return ZIP_CODE_REGEX.test(trimmed) ? trimmed : null;
};

export const getBrowseZipCookie = () => {
  if (typeof document === 'undefined') return null;

  const cookiePrefix = `${BROWSE_ZIP_COOKIE_NAME}=`;
  const cookieEntry = document.cookie
    .split(';')
    .map((part) => part.trim())
    .find((part) => part.startsWith(cookiePrefix));

  if (!cookieEntry) return null;

  const encodedValue = cookieEntry.slice(cookiePrefix.length);
  const decodedValue = decodeURIComponent(encodedValue);
  return normalizeBrowseZip(decodedValue);
};

export const setBrowseZipCookie = (zipCode) => {
  if (typeof document === 'undefined') return;
  const normalizedZip = normalizeBrowseZip(zipCode);
  if (!normalizedZip) return;

  document.cookie = `${BROWSE_ZIP_COOKIE_NAME}=${encodeURIComponent(normalizedZip)}; Max-Age=${BROWSE_ZIP_COOKIE_MAX_AGE_SECONDS}; Path=/; SameSite=Lax`;
};
