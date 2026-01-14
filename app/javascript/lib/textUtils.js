import React from 'react';

/**
 * Converts URLs in text to clickable links
 * @param {string} text - The text to process
 * @returns {Array} Array of React elements (text and links)
 */
export const linkifyText = (text) => {
  if (!text) return text;

  // URL regex pattern - matches http://, https://, and www. URLs
  const urlRegex = /(https?:\/\/[^\s]+|www\.[^\s]+)/gi;
  const parts = [];
  let lastIndex = 0;
  let match;

  while ((match = urlRegex.exec(text)) !== null) {
    // Add text before the URL
    if (match.index > lastIndex) {
      parts.push(text.substring(lastIndex, match.index));
    }

    // Add the URL as a link
    let url = match[0];
    let href = url;

    // Add http:// if it's a www. URL
    if (url.startsWith('www.')) {
      href = `https://${url}`;
    }

    parts.push(
      <a
        key={match.index}
        href={href}
        target="_blank"
        rel="noopener noreferrer"
        className="underline hover:opacity-80"
      >
        {url}
      </a>
    );

    lastIndex = match.index + match[0].length;
  }

  // Add remaining text after the last URL
  if (lastIndex < text.length) {
    parts.push(text.substring(lastIndex));
  }

  // If no URLs were found, return the original text
  return parts.length > 0 ? parts : text;
};

/**
 * Parses the page state from a URL path
 * @param {string} path - The URL path to parse
 * @returns {Object} Object with page type and groupShortName (if applicable)
 * @returns {string} returns.page - The page type: 'browse', 'groupPage', or 'home'
 * @returns {string|null} returns.groupShortName - The group short name if on a group page, null otherwise
 */
export const parsePageFromPath = (path) => {
  if (path === '/browse') {
    return { page: 'browse', groupShortName: null };
  }
  const groupMatch = path.match(/^\/g\/([^\/]+)/);
  if (groupMatch) {
    return { page: 'groupPage', groupShortName: groupMatch[1] };
  }
  return { page: 'home', groupShortName: null };
};

/**
 * Gets group page information from the current URL or history state
 * @returns {Object} Object with isGroupPage flag and groupShortName
 * @returns {boolean} returns.isGroupPage - Whether the current page is a group page
 * @returns {string|null} returns.groupShortName - The group short name if on a group page, null otherwise
 */
export const getGroupPageInfo = () => {
  if (typeof window !== 'undefined') {
    // First check history state for groupShortName
    const state = window.history.state;
    if (state && state.groupShortName) {
      return { isGroupPage: true, groupShortName: state.groupShortName };
    }
    // Fallback: check URL
    const path = window.location.pathname;
    const parsed = parsePageFromPath(path);
    if (parsed.page === 'groupPage') {
      return { isGroupPage: true, groupShortName: parsed.groupShortName };
    }
  }
  return { isGroupPage: false, groupShortName: null };
};

