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

