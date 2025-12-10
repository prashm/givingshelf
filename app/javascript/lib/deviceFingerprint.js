// Device fingerprinting utility
// Collects device attributes and generates a consistent hash

const generateDeviceFingerprint = async () => {
  const attributes = {};

  // Basic browser information
  if (navigator.userAgent) {
    attributes.userAgent = navigator.userAgent;
  }

  if (navigator.platform) {
    attributes.platform = navigator.platform;
  }

  if (navigator.language) {
    attributes.language = navigator.language;
  }

  if (navigator.languages && navigator.languages.length > 0) {
    attributes.languages = navigator.languages.join(',');
  }

  // Screen information
  if (screen.width && screen.height) {
    attributes.screenResolution = `${screen.width}x${screen.height}`;
    attributes.colorDepth = screen.colorDepth || null;
    attributes.pixelDepth = screen.pixelDepth || null;
  }

  // Timezone
  try {
    attributes.timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    attributes.timezoneOffset = new Date().getTimezoneOffset();
  } catch (e) {
    // Fallback if timezone API is not available
    attributes.timezoneOffset = new Date().getTimezoneOffset();
  }

  // Canvas fingerprint
  try {
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    if (ctx) {
      canvas.width = 200;
      canvas.height = 50;
      ctx.textBaseline = 'top';
      ctx.font = '14px Arial';
      ctx.textBaseline = 'alphabetic';
      ctx.fillStyle = '#f60';
      ctx.fillRect(125, 1, 62, 20);
      ctx.fillStyle = '#069';
      ctx.fillText('Device fingerprint 🔒', 2, 15);
      ctx.fillStyle = 'rgba(102, 204, 0, 0.7)';
      ctx.fillText('Device fingerprint 🔒', 4, 17);
      const canvasData = canvas.toDataURL();
      attributes.canvas = canvasData.substring(0, 100); // Use first 100 chars for hash
    }
  } catch (e) {
    // Canvas fingerprinting not available
  }

  // WebGL fingerprint
  try {
    const canvas = document.createElement('canvas');
    const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
    if (gl) {
      const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
      if (debugInfo) {
        attributes.webglVendor = gl.getParameter(debugInfo.UNMASKED_VENDOR_WEBGL);
        attributes.webglRenderer = gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL);
      }
      // Additional WebGL parameters
      attributes.webglVersion = gl.getParameter(gl.VERSION);
      attributes.webglShadingLanguageVersion = gl.getParameter(gl.SHADING_LANGUAGE_VERSION);
    }
  } catch (e) {
    // WebGL not available
  }

  // Hardware concurrency
  if (navigator.hardwareConcurrency) {
    attributes.hardwareConcurrency = navigator.hardwareConcurrency;
  }

  // Device memory (if available)
  if (navigator.deviceMemory) {
    attributes.deviceMemory = navigator.deviceMemory;
  }

  // Touch support
  attributes.touchSupport = 'ontouchstart' in window || navigator.maxTouchPoints > 0;

  // Do Not Track
  if (navigator.doNotTrack !== undefined) {
    attributes.doNotTrack = navigator.doNotTrack;
  }

  // Cookie enabled
  attributes.cookieEnabled = navigator.cookieEnabled;

  // Generate hash from collected attributes
  const fingerprintString = JSON.stringify(attributes);
  const hash = await hashString(fingerprintString);
  
  return {
    hash,
    attributes
  };
};

// Simple hash function using Web Crypto API
const hashString = async (str) => {
  if (typeof window !== 'undefined' && window.crypto && window.crypto.subtle) {
    try {
      const encoder = new TextEncoder();
      const data = encoder.encode(str);
      const hashBuffer = await window.crypto.subtle.digest('SHA-256', data);
      const hashArray = Array.from(new Uint8Array(hashBuffer));
      const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
      return hashHex;
    } catch (e) {
      // Fallback to simple hash if crypto API fails
      return simpleHash(str);
    }
  } else {
    // Fallback for browsers without crypto API
    return simpleHash(str);
  }
};

// Fallback simple hash function
const simpleHash = (str) => {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32bit integer
  }
  return Math.abs(hash).toString(16);
};

export default generateDeviceFingerprint;
