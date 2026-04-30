/**
 * Maps Google Books API / autocomplete suggestion shapes into fields the app
 * expects for book forms and POST /api/items/wishlist (Google-agnostic fields).
 */

export function upgradeThumbnailToHttps(url) {
  if (!url || typeof url !== 'string') return '';
  return url.replace(/^http:/, 'https:');
}

/** Truncate at maxLength, preferring a sentence boundary (., !, ?). */
export function truncateSummaryIntelligently(text, maxLength = 1000) {
  if (!text || text.length <= maxLength) {
    return text || '';
  }
  const truncated = text.substring(0, maxLength);
  const lastPeriod = truncated.lastIndexOf('.');
  const lastExclamation = truncated.lastIndexOf('!');
  const lastQuestion = truncated.lastIndexOf('?');
  const lastSentenceEnd = Math.max(lastPeriod, lastExclamation, lastQuestion);
  if (lastSentenceEnd > 0) {
    return truncated.substring(0, lastSentenceEnd + 1).trim();
  }
  return truncated.trim();
}

export function publishedYearFromGoogleDate(publishedDate) {
  const m = String(publishedDate || '').match(/(18|19|20)\d{2}/);
  const y = m ? parseInt(m[0], 10) : new Date().getFullYear();
  const maxY = new Date().getFullYear();
  return Math.min(Math.max(y, 1801), maxY);
}

/** Returns '' or a 10- or 13-digit string suitable for the Book model. */
export function sanitizeIsbnForBookModel(raw) {
  if (raw == null || raw === '') return '';
  const digits = String(raw).replace(/\D/g, '');
  if (digits.length === 10) return digits;
  if (digits.length >= 13) return digits.slice(0, 13);
  return '';
}

/**
 * @param {object} book - Autocomplete / mapVolumeToSuggestion shape:
 *   { title, authors[], publishedDate, description, isbn, thumbnail, categories[] }
 * @returns {{ title, author, summary, genre, published_year, isbn, cover_image_url }}
 */
export function normalizedBookFieldsFromGoogleAutocomplete(book) {
  const authors = Array.isArray(book.authors) ? book.authors : [];
  const author = authors.length ? authors.join(', ') : 'Unknown';
  const categories = Array.isArray(book.categories) ? book.categories : [];
  const genre = (categories[0] || '').toString().slice(0, 100);

  let summary = (book.description || '').trim();
  if (summary.length < 10) {
    const t = (book.title || 'this book').trim() || 'this book';
    summary = `A community member is interested in "${t}". ${summary}`.trim();
  }
  summary = truncateSummaryIntelligently(summary, 1000);

  return {
    title: (book.title || 'Untitled').trim().slice(0, 255),
    author: author.slice(0, 255),
    summary,
    genre,
    published_year: publishedYearFromGoogleDate(book.publishedDate),
    isbn: sanitizeIsbnForBookModel(book.isbn),
    cover_image_url: upgradeThumbnailToHttps(book.thumbnail || '')
  };
}

