/**
 * Open Library book lookup helpers.
 * Used as a low-volume ISBN fallback when Google Books has no match.
 */

/**
 * Exact ISBN lookup. Returns the same suggestion shape as mapVolumeToSuggestion
 * in googleBooksApi.js (id, title, authors, publisher, publishedDate, description,
 * isbn, thumbnail, categories).
 */
export async function searchOpenLibraryByIsbn(isbn, { signal } = {}) {
  if (!isbn) return [];

  const url = new URL('https://openlibrary.org/search.json');
  url.searchParams.set('q', `isbn:${isbn}`);
  url.searchParams.set('limit', '1');
  url.searchParams.set(
    'fields',
    'key,title,author_name,first_publish_year,publisher,isbn,cover_i'
  );

  const response = await fetch(url.toString(), { signal });
  if (!response.ok) {
    throw new Error('Failed to fetch book from Open Library');
  }
  const data = await response.json();
  const doc = data.docs?.[0];
  if (!doc) return [];

  // Prefer the ISBN the student looked up so wishlist/listings keep that edition key.
  const cover = doc.cover_i
    ? `https://covers.openlibrary.org/b/id/${doc.cover_i}-M.jpg`
    : `https://covers.openlibrary.org/b/isbn/${isbn}-M.jpg`;

  return [ {
    id: `ol:${doc.key || isbn}`,
    title: doc.title || 'Unknown Title',
    authors: Array.isArray(doc.author_name) && doc.author_name.length > 0
      ? doc.author_name
      : [ 'Unknown Author' ],
    publisher: Array.isArray(doc.publisher) ? (doc.publisher[0] || '') : '',
    publishedDate: doc.first_publish_year ? String(doc.first_publish_year) : '',
    description: '',
    isbn,
    thumbnail: cover,
    categories: [],
  } ];
}
