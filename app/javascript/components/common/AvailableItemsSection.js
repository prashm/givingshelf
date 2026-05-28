import React from 'react';
import * as Constants from '../../lib/constants';
import ItemCard from './ItemCard';

const AvailableItemsSection = ({
  title = 'Available Books',
  books = [],
  resultsLabel,
  onBookSelect,
  paginationMeta,
  loadMoreBooks,
  loading = false,
  emptyMessage = 'No books available yet.',
  itemType = Constants.ITEM_TYPE_BOOK
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
            {books.map((item) => (
              <ItemCard
                key={item.id}
                item={item}
                itemType={itemType}
                onSelect={onBookSelect}
              />
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

export default AvailableItemsSection;

