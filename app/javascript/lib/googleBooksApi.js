import { searchOpenLibraryByIsbn } from './openLibraryApi';

const CACHE_TTL_MS = 15 * 60 * 1000;
const cache = new Map();
const MIN_QUERY_LENGTH = 4;

async function fetchVolumes(q, signal) {
  const apiKey = typeof document !== 'undefined'
    ? document.querySelector('meta[name="google-books-api-key"]')?.getAttribute('content')
    : null;
  const url = new URL('https://www.googleapis.com/books/v1/volumes');
  url.searchParams.set('q', q);
  url.searchParams.set('maxResults', '8');
  url.searchParams.set('printType', 'books');
  url.searchParams.set('country', 'US');
  if (apiKey) url.searchParams.set('key', apiKey);

  const response = await fetch(url.toString(), { signal });
  if (!response.ok) {
    throw new Error('Failed to fetch books');
  }
  const data = await response.json();
  return data.items || [];
}

/**
 * Fetches up to 8 book suggestions from Google Books.
 * When `isbn` is passed, searches with q=isbn:VALUE only; if Google returns
 * nothing, falls back to Open Library for that ISBN.
 * Otherwise runs a full-text Google query (requires at least 4 characters).
 * Results are cached in-memory for 15 minutes per tab session.
 */
export async function searchGoogleBooks(query, { signal, isbn = null } = {}) {
  const trimmed = (query || '').trim();
  if (isbn) {
    const cacheKey = `isbn:${isbn}`;
    const hit = cache.get(cacheKey);
    if (hit && Date.now() - hit.at < CACHE_TTL_MS) {
      return hit.results;
    }

    let results = (await fetchVolumes(`isbn:${isbn}`, signal))
      .map((item) => mapVolumeToSuggestion(item));

    if (results.length === 0) {
      try {
        results = await searchOpenLibraryByIsbn(isbn, { signal });
      } catch (e) {
        if (e.name === 'AbortError') throw e;
        console.error('Open Library ISBN fallback failed:', e);
        results = [];
      }
    }

    cache.set(cacheKey, { at: Date.now(), results });
    return results;
  }

  if (trimmed.length < MIN_QUERY_LENGTH) {
    return [];
  }

  const cacheKey = trimmed.toLowerCase();
  const hit = cache.get(cacheKey);
  if (hit && Date.now() - hit.at < CACHE_TTL_MS) {
    return hit.results;
  }

  const items = await fetchVolumes(trimmed, signal);
  const results = items.map((item) => mapVolumeToSuggestion(item));
  cache.set(cacheKey, { at: Date.now(), results });
  return results;
}

export function mapVolumeToSuggestion(item) {
  return {
    id: item.id,
    title: item.volumeInfo?.title || 'Unknown Title',
    authors: item.volumeInfo?.authors || [ 'Unknown Author' ],
    publisher: item.volumeInfo?.publisher || '',
    publishedDate: item.volumeInfo?.publishedDate || '',
    description: item.volumeInfo?.description || '',
    isbn: item.volumeInfo?.industryIdentifiers?.find((id) => id.type === 'ISBN_13')?.identifier
      || item.volumeInfo?.industryIdentifiers?.find((id) => id.type === 'ISBN_10')?.identifier
      || '',
    thumbnail: item.volumeInfo?.imageLinks?.thumbnail
      || item.volumeInfo?.imageLinks?.smallThumbnail
      || '',
    categories: item.volumeInfo?.categories || [],
  };
}
