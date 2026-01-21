import React from 'react';

const AvailableBooksSection = ({
  title = 'Available Books',
  books = [],
  resultsLabel,
  onBookSelect,
  paginationMeta,
  loadMoreBooks,
  loading = false,
  emptyMessage = 'No books available yet.'
}) => {
  const hasMore = Boolean(paginationMeta?.hasMore) && books.length < (paginationMeta?.total ?? 0);

  return (
    <div className="mb-12">
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold">{title}</h2>
        {resultsLabel && (
          <span className="text-gray-600 text-sm">
            {resultsLabel}
          </span>
        )}
      </div>

      {books.length > 0 ? (
        <>
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {books.map((book) => (
              <div
                key={book.id}
                className="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow cursor-pointer"
                onClick={() => onBookSelect?.(book)}
              >
                <div className="flex justify-center items-center bg-gray-50" style={{ height: '200px' }}>
                  {book.cover_image_url ? (
                    <img
                      src={book.cover_image_url}
                      alt={book.title}
                      className="img-box"
                    />
                  ) : (
                    <div className="flex flex-col items-center justify-center text-gray-400">
                      <svg className="w-16 h-16 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                      </svg>
                      <span className="text-sm">No Cover</span>
                    </div>
                  )}
                </div>
                <div className="p-4">
                  <h3 className="font-semibold text-lg mb-2 line-clamp-2">{book.title}</h3>
                  <p className="text-gray-600 mb-2">by {book.author}</p>
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-500">{book.genre}</span>
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${book.condition === 'excellent' ? 'bg-green-100 text-green-800' :
                      book.condition === 'good' ? 'bg-blue-100 text-blue-800' :
                        book.condition === 'fair' ? 'bg-yellow-100 text-yellow-800' :
                          'bg-red-100 text-red-800'
                      }`}>
                      {book.condition}
                    </span>
                  </div>
                </div>
              </div>
            ))}
          </div>

          {hasMore && (
            <div className="mt-6 text-center">
              <button
                onClick={loadMoreBooks}
                disabled={loading}
                className="border border-blue-200 bg-blue-50 text-blue-800 px-6 py-2 rounded-md enabled:hover:bg-blue-200 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
              >
                {loading ? 'Loading...' : 'Show more...'}
              </button>
            </div>
          )}
        </>
      ) : (
        !loading && (
          <div className="text-center py-12">
            <p className="text-gray-600 text-lg">{emptyMessage}</p>
          </div>
        )
      )}
    </div>
  );
};

export default AvailableBooksSection;

