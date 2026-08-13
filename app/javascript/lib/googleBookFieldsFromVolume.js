/**
 * Maps Google Books API / autocomplete suggestion shapes into fields the app
 * expects for book forms and POST /api/items/wishlist (Google-agnostic fields).
 */

/** Prefill for wishlist request modal; backend falls back to BookService::DEFAULT_WISHLIST_MESSAGE if blank. */
export const DEFAULT_WISHLIST_MESSAGE = "I'd love this book if anyone has a copy. Thanks!";

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

/**
 * Returns '' or a compact ISBN-10 / ISBN-13 string for the Book model.
 * Preserves a trailing X check digit on ISBN-10; the model converts to ISBN-13.
 */
export function sanitizeIsbnForBookModel(raw) {
  if (raw == null || raw === '') return '';
  const compact = String(raw).toUpperCase().replace(/[^0-9X]/g, '');
  if (/^\d{13}$/.test(compact)) return compact;
  if (/^\d{9}[\dX]$/.test(compact)) return compact;
  // Prefer a leading 13-digit run when more digits are present (e.g. with extra noise).
  const thirteen = compact.match(/\d{13}/);
  if (thirteen) return thirteen[0];
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

