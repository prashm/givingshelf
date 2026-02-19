import React from 'react';
import * as Constants from './constants';

/**
 * Truncates text to a maximum length with ellipsis
 * @param {string} text - The text to truncate
 * @param {number} maxChars - Maximum character length (default 50)
 * @returns {string|null} Truncated text or null if invalid input
 */
export const truncateText = (text, maxChars = 50) => {
  if (!text || typeof text !== 'string') return null;
  const trimmed = text.trim();
  if (trimmed.length <= maxChars) return trimmed;
  return trimmed.slice(0, maxChars).trim() + '...';
};

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
 * @returns {Object} Object with page, itemType, and groupShortName
 */
export const parsePageFromPath = (path) => {
  if (path === '/books') {
    return { page: 'books', itemType: Constants.ITEM_TYPE_BOOK, groupShortName: null };
  }
  if (path === '/toys') {
    return { page: 'toys', itemType: Constants.ITEM_TYPE_TOY, groupShortName: null };
  }
  const bookDetailMatch = path.match(/^\/books\/(\d+)$/);
  if (bookDetailMatch) {
    return { page: 'itemDetails', itemId: parseInt(bookDetailMatch[1], 10), itemType: Constants.ITEM_TYPE_BOOK, groupShortName: null };
  }
  const toyDetailMatch = path.match(/^\/toys\/(\d+)$/);
  if (toyDetailMatch) {
    return { page: 'itemDetails', itemId: parseInt(toyDetailMatch[1], 10), itemType: Constants.ITEM_TYPE_TOY, groupShortName: null };
  }
  if (path.startsWith('/my-groups')) {
    return { page: 'myGroups', groupShortName: null, itemType: null };
  }
  // /g/:short_name/books or /g/:short_name/toys
  const groupBooksMatch = path.match(/^\/g\/([^/]+)\/books$/);
  if (groupBooksMatch) {
    return { page: 'groupBrowse', groupShortName: groupBooksMatch[1], itemType: Constants.ITEM_TYPE_BOOK };
  }
  const groupToysMatch = path.match(/^\/g\/([^/]+)\/toys$/);
  if (groupToysMatch) {
    return { page: 'groupBrowse', groupShortName: groupToysMatch[1], itemType: Constants.ITEM_TYPE_TOY };
  }
  // /g/:short_name (group landing)
  const groupMatch = path.match(/^\/g\/([^/]+)$/);
  if (groupMatch) {
    return { page: 'groupLanding', groupShortName: groupMatch[1], itemType: null };
  }
  if (path === '/item_request_details') {
    return { page: 'itemRequestDetails', groupShortName: null, itemType: null };
  }
  return { page: 'home', groupShortName: null, itemType: null };
};

/**
 * Gets group page information from the current URL or history state
 * @returns {Object} Object with isGroupPage flag and groupShortName
 * @returns {boolean} returns.isGroupPage - Whether the current page is a group page
 * @returns {string|null} returns.groupShortName - The group short name if on a group page, null otherwise
 */
export const getGroupPageInfo = () => {
  if (typeof window !== 'undefined') {
    const state = window.history.state;
    if (state && state.groupShortName) {
      return { isGroupPage: true, groupShortName: state.groupShortName };
    }
    const path = window.location.pathname;
    const parsed = parsePageFromPath(path);
    if (parsed.page === 'groupLanding' || parsed.page === 'groupBrowse') {
      return { isGroupPage: true, groupShortName: parsed.groupShortName };
    }
  }
  return { isGroupPage: false, groupShortName: null };
};

