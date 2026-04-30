import React from 'react';

function httpsThumbnail(url) {
  if (!url || typeof url !== 'string') return null;
  return url.replace(/^http:/, 'https:');
}

function publishedYearLabel(publishedDate) {
  if (!publishedDate) return null;
  const y = new Date(publishedDate).getFullYear();
  return Number.isFinite(y) ? y : null;
}

/**
 * One row in the Google Books suggestion dropdown (Add Book, browse search, etc.).
 * `book` matches useBookAutocomplete / mapVolumeToSuggestion: id, title, authors[], thumbnail, publisher, publishedDate, isbn
 */
export function GoogleBookSuggestionRow({ book, onSelect, isHighlighted, onMouseDown }) {
  const authors = Array.isArray(book.authors) ? book.authors : [];
  const year = publishedYearLabel(book.publishedDate);
  const thumb = httpsThumbnail(book.thumbnail);

  return (
    <div
      onClick={() => onSelect?.(book)}
      onMouseDown={onMouseDown}
      className={`px-4 py-3 cursor-pointer border-b border-gray-100 last:border-b-0 hover:bg-gray-50 ${
        isHighlighted ? 'bg-blue-50' : ''
      }`}
    >
      <div className="flex items-start space-x-3">
        {thumb && (
          <img
            src={thumb}
            alt={book.title}
            className="w-12 h-16 object-cover rounded border flex-shrink-0"
            onError={(e) => {
              e.target.style.display = 'none';
            }}
          />
        )}
        <div className="flex-1 min-w-0 ml-4">
          <h4 className="text-sm font-medium text-gray-900 truncate">
            {book.title}
          </h4>
          <p className="text-sm text-gray-600 truncate">
            by {authors.join(', ')}
          </p>
          <div className="flex items-center space-x-2 mt-1">
            {book.publisher && (
              <span className="text-xs text-gray-500">
                {book.publisher}
              </span>
            )}
            {book.publishedDate && (
              <span className="text-xs text-gray-500">
                • {year ?? '—'}
              </span>
            )}
          </div>
          {book.isbn && (
            <span className="text-xs text-gray-400">
              ISBN: {book.isbn}
            </span>
          )}
        </div>
      </div>
    </div>
  );
}

/**
 * Fixed panel shell matching Add Book dropdown (border, shadow, scroll).
 * Position via `style` (top, left, width) from input getBoundingClientRect.
 */
export function GoogleBookSuggestionDropdown({ style, children, className = '' }) {
  return (
    <div
      className={`fixed bg-white border border-gray-300 rounded-md shadow-lg max-h-80 overflow-y-auto z-[9999] ${className}`}
      style={style}
    >
      {children}
    </div>
  );
}

export function GoogleBookNoResultsDropdown({ style, searchText }) {
  return (
    <div
      className="fixed bg-white border border-gray-300 rounded-md shadow-lg z-[9999]"
      style={style}
    >
      <div className="px-4 py-3 text-sm text-gray-500">
        No books found for &quot;{searchText}&quot;
      </div>
    </div>
  );
}
