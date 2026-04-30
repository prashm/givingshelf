/**
 * Fetches up to 8 book suggestions from Google Books (same as useBookAutocomplete).
 */
export async function searchGoogleBooks(query, { signal } = {}) {
  if (!query || query.length < 2) {
    return [];
  }
  const apiKey = typeof document !== 'undefined'
    ? document.querySelector('meta[name="google-books-api-key"]')?.getAttribute('content')
    : null;
  const url = new URL('https://www.googleapis.com/books/v1/volumes');
  url.searchParams.set('q', query);
  url.searchParams.set('maxResults', '8');
  if (apiKey) url.searchParams.set('key', apiKey);
  const response = await fetch(url.toString(), { signal });
  if (!response.ok) {
    throw new Error('Failed to fetch books');
  }
  const data = await response.json();
  if (!data.items || data.items.length === 0) {
    return [];
  }
  return data.items.map((item) => mapVolumeToSuggestion(item));
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
