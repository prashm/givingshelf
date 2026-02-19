import React, { useState, useEffect } from 'react';
import { PencilIcon, TrashIcon, EyeIcon, GiftIcon } from '@heroicons/react/24/outline';
import { useItems } from '../../contexts/ItemContext';
import * as Constants from '../../lib/constants';
import { truncateText } from '../../lib/textUtils';

const MyItems = ({ currentUser, setCurrentPage, onEditBook, onEditToy, onViewBook, fromProfile = false }) => {
  const [myItems, setMyItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all'); // all, Books, Toys
  const { deleteItem: deleteItemFromAPI } = useItems();
  const [deletingItemId, setDeletingItemId] = useState(null);

  useEffect(() => {
    const fetchItems = async () => {
      try {
        const response = await fetch('/api/items/my_items');
        if (!response.ok) {
          throw new Error('Failed to fetch items');
        }
        const data = await response.json();
        setMyItems(data.items || data.books || []);
      } catch (error) {
        console.error('Error fetching items:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchItems();
  }, []);

  const handleEditItem = (item) => {
    if (item.type === Constants.ITEM_TYPE_BOOK && onEditBook) {
      onEditBook(item.id);
    } else if (item.type === Constants.ITEM_TYPE_TOY && onEditToy) {
      onEditToy(item.id);
    }
  };

  const handleDeleteItem = async (itemId) => {
    if (window.confirm('Are you sure you want to delete this item? This action cannot be undone.')) {
      setDeletingItemId(itemId);
      try {
        const result = await deleteItemFromAPI(itemId);
        if (result.success) {
          setMyItems(prev => prev.filter(item => item.id !== itemId));
        } else {
          alert(result.error || 'Failed to delete item. Please try again.');
        }
      } catch (error) {
        console.error('Error deleting item:', error);
        alert('An error occurred while deleting the item. Please try again.');
      } finally {
        setDeletingItemId(null);
      }
    }
  };

  const handleViewItem = (item) => {
    // Pass item so ItemDetailPage can use id; ItemDetailPage performs the single fetch
    if (onViewBook) {
      onViewBook(item);
    } else {
      setCurrentPage('itemDetails', { selectedBook: item, itemDetailSource: 'myItems' });
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 0: // Available
        return 'bg-green-100 text-green-800';
      case 1: // Requested
        return 'bg-yellow-100 text-yellow-800';
      case 2: // Donated
        return 'bg-blue-100 text-blue-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  const filteredItems = myItems.filter(item => {
    if (filter === 'all') return true;
    return item.type === filter;
  });

  const bookCount = myItems.filter(i => i.type === Constants.ITEM_TYPE_BOOK).length;
  const toyCount = myItems.filter(i => i.type === Constants.ITEM_TYPE_TOY).length;

  if (loading) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-6xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center justify-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            <span className="ml-2 text-gray-600">Loading your items...</span>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto py-8 px-4 max-w-6xl">
      <div className="bg-white rounded-lg shadow-md p-6">
        {/* Header with Back Button */}
        <div className="mb-6">
          {fromProfile && (
            <button
              onClick={() => window.history.back()}
              className="flex items-center gap-2 text-blue-600 hover:text-blue-700 mb-4"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
              </svg>
              Back to Profile
            </button>
          )}
          <div className="flex items-center justify-between">
            <h2 className="text-3xl font-bold text-gray-900">My Items</h2>
          </div>
        </div>

        {/* Filter Select */}
        <div className="mb-6">
          <select
            id="filter-select"
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            className="w-full md:w-auto px-4 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm"
            style={{ appearance: 'auto' }}
          >
            <option value="all">All Items ({myItems.length})</option>
            <option value={Constants.ITEM_TYPE_BOOK}>Books ({bookCount})</option>
            <option value={Constants.ITEM_TYPE_TOY}>Toys ({toyCount})</option>
          </select>
        </div>

        {/* Items Grid */}
        {filteredItems.length === 0 ? (
          <div className="text-center py-12">
            <div className="text-6xl mb-4">📦</div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">No items found</h3>
            <p className="text-gray-500 mb-6">
              {filter === 'all'
                ? "You haven't added any items yet."
                : `You don't have any ${filter === Constants.ITEM_TYPE_BOOK ? 'books' : 'toys'}.`
              }
            </p>
            {filter === 'all' && (
              <div className="flex flex-wrap justify-center gap-4">
                <button
                  onClick={() => setCurrentPage('donate', { donateItemType: Constants.ITEM_TYPE_BOOK })}
                  className="px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700"
                >
                  Add Book
                </button>
                <button
                  onClick={() => setCurrentPage('donate', { donateItemType: Constants.ITEM_TYPE_TOY })}
                  className="px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700"
                >
                  Add Toy
                </button>
              </div>
            )}
          </div>
        ) : (
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredItems.map((item) => {
              const isBook = item.type === Constants.ITEM_TYPE_BOOK;
              return (
                <div
                  key={item.id}
                  className="bg-white border border-gray-200 rounded-lg overflow-hidden hover:shadow-lg transition-shadow"
                >
                  {/* Cover */}
                  <div className="h-48 bg-gray-100 flex items-center justify-center">
                    {item.cover_image_url ? (
                      <img
                        src={item.cover_image_url}
                        alt={item.title}
                        className="img-box"
                      />
                    ) : (
                      <div className="text-gray-400 text-center">
                        {isBook ? (
                          <svg className="w-16 h-16 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                          </svg>
                        ) : (
                          <GiftIcon className="w-16 h-16 mx-auto mb-2" strokeWidth={1.5} />
                        )}
                        <div className="text-sm">No Cover</div>
                      </div>
                    )}
                  </div>

                  {/* Item Info */}
                  <div className="p-4">
                    <h3 className="font-semibold text-lg mb-2 line-clamp-2">{item.title}</h3>
                    {isBook ? (
                      <>
                        {(item.author) && (
                          <p className="text-gray-500 text-xs mb-2">
                            by {item.author}
                          </p>
                        )}
                        {item.summary && (
                          <p className="text-gray-600 text-sm mb-2 line-clamp-2" title={item.summary}>
                            {truncateText(item.summary, 40)}
                          </p>
                        )}
                      </>
                    ) : (
                      <>
                        {(item.brand || item.age_range) && (
                          <p className="text-gray-500 text-xs mb-2">
                            {[item.brand, item.age_range].filter(Boolean).join(' • ')}
                          </p>
                        )}
                        {item.summary && (
                          <p className="text-gray-600 text-sm mb-2 line-clamp-2" title={item.summary}>
                            {truncateText(item.summary, 40)}
                          </p>
                        )}
                      </>
                    )}

                    <div className="flex items-center justify-between mb-3">
                      <span className={`px-2 py-1 rounded-full text-xs font-medium ${item.condition === 'excellent' ? 'bg-green-100 text-green-800' :
                        item.condition === 'good' ? 'bg-blue-100 text-blue-800' :
                          item.condition === 'fair' ? 'bg-yellow-100 text-yellow-800' :
                            'bg-red-100 text-red-800'
                        }`}>
                        {item.condition}
                      </span>

                      <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(item.status)}`}>
                        {item.status_display}
                      </span>
                    </div>

                    <div className="text-xs text-gray-500 mb-4">
                      Added on {new Date(item.created_at).toLocaleDateString()}
                    </div>

                    {/* Action Buttons */}
                    <div className="flex gap-2">
                      <button
                        onClick={() => handleViewItem(item)}
                        className="flex-1 flex items-center justify-center gap-1 px-3 py-2 bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200 transition-colors"
                      >
                        <EyeIcon className="h-4 w-4" />
                        View
                      </button>

                      <button
                        onClick={() => handleEditItem(item)}
                        className="flex-1 flex items-center justify-center gap-1 px-3 py-2 bg-blue-100 text-blue-700 rounded-md hover:bg-blue-200 transition-colors"
                      >
                        <PencilIcon className="h-4 w-4" />
                        Edit
                      </button>

                      <button
                        onClick={() => handleDeleteItem(item.id)}
                        disabled={deletingItemId === item.id}
                        className="px-3 py-2 bg-red-100 text-red-700 rounded-md hover:bg-red-200 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                        title="Delete item"
                      >
                        {deletingItemId === item.id ? (
                          <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-red-700"></div>
                        ) : (
                          <TrashIcon className="h-4 w-4" />
                        )}
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

export default MyItems;
