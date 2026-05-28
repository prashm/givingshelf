import React from 'react';
import * as Constants from '../../lib/constants';
import ItemCard from './ItemCard';

const WishlistItemsSection = ({
  title,
  items = [],
  itemType = Constants.ITEM_TYPE_BOOK,
  loading = false,
  paginationMeta = null,
  onLoadMore,
  onSelectItem,
  onFulfillWish,
  onPlaceRequest
}) => {
  const hasMore = Boolean(paginationMeta?.hasMore) && items.length < (paginationMeta?.total ?? 0);

  if (!loading && items.length === 0) return null;

  return (
    <div className="mb-12">
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold">{title}</h2>
        {paginationMeta?.total > 0 && (
          <span className="text-gray-600 text-sm">
            {paginationMeta.total} {paginationMeta.total === 1 ? 'Item' : 'Items'}
          </span>
        )}
      </div>

      {loading && items.length === 0 ? (
        <div className="text-center py-8 text-gray-600">Loading community wishlist...</div>
      ) : (
        <>
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {items.map((item) => (
              <ItemCard
                key={item.id}
                item={item}
                itemType={itemType}
                onSelect={onSelectItem}
                actions={(
                  <div className="flex flex-col gap-2">
                    <button
                      type="button"
                      className="w-full text-white py-2 px-3 rounded-md transition-colors text-sm font-medium"
                      style={{ backgroundColor: 'rgb(247, 123, 36)' }}
                      onClick={(e) => {
                        e.stopPropagation();
                        onFulfillWish?.(item);
                      }}
                    >
                      Fulfill the wish
                    </button>
                    <button
                      type="button"
                      className="w-full bg-emerald-600 text-white py-2 px-3 rounded-md hover:bg-emerald-700 transition-colors text-sm font-medium"
                      onClick={(e) => {
                        e.stopPropagation();
                        onPlaceRequest?.(item);
                      }}
                    >
                      Place request
                    </button>
                  </div>
                )}
              />
            ))}
          </div>

          {hasMore && (
            <div className="mt-6 text-center">
              <button
                type="button"
                onClick={onLoadMore}
                disabled={loading}
                className="border border-blue-200 bg-blue-50 text-blue-800 px-6 py-2 rounded-md enabled:hover:bg-blue-200 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
              >
                {loading ? 'Loading...' : 'Show more...'}
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
};

export default WishlistItemsSection;
