import React, { useState, useEffect } from 'react';
import { PencilIcon, TrashIcon, EyeIcon } from '@heroicons/react/24/outline';

const MyBooks = ({ currentUser, setCurrentPage, onEditBook }) => {
  const [myBooks, setMyBooks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all'); // all, available, requested, donated

  useEffect(() => {
    // TODO: Fetch user's books from API
    // For now, using mock data
    const mockBooks = [
      {
        id: 1,
        title: 'The Great Gatsby',
        author: 'F. Scott Fitzgerald',
        condition: 'excellent',
        status: 'available',
        cover_image_url: null,
        created_at: '2024-01-15'
      },
      {
        id: 2,
        title: 'To Kill a Mockingbird',
        author: 'Harper Lee',
        condition: 'good',
        status: 'requested',
        cover_image_url: null,
        created_at: '2024-01-10'
      }
    ];
    
    setTimeout(() => {
      setMyBooks(mockBooks);
      setLoading(false);
    }, 1000);
  }, []);

  const handleEditBook = (bookId) => {
    if (onEditBook) {
      onEditBook(bookId);
    } else {
      console.log('Edit book:', bookId);
    }
  };

  const handleDeleteBook = (bookId) => {
    if (window.confirm('Are you sure you want to delete this book?')) {
      // TODO: Delete book from API
      setMyBooks(prev => prev.filter(book => book.id !== bookId));
    }
  };

  const handleViewBook = (bookId) => {
    // TODO: Navigate to book detail page
    console.log('View book:', bookId);
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'available':
        return 'bg-green-100 text-green-800';
      case 'requested':
        return 'bg-yellow-100 text-yellow-800';
      case 'donated':
        return 'bg-blue-100 text-blue-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  const getStatusText = (status) => {
    switch (status) {
      case 'available':
        return 'Available';
      case 'requested':
        return 'Requested';
      case 'donated':
        return 'Donated';
      default:
        return 'Unknown';
    }
  };

  const filteredBooks = myBooks.filter(book => {
    if (filter === 'all') return true;
    return book.status === filter;
  });

  if (loading) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-6xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center justify-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            <span className="ml-2 text-gray-600">Loading your books...</span>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto py-8 px-4 max-w-6xl">
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-3xl font-bold text-gray-900">My Books</h2>
          <button
            onClick={() => setCurrentPage('donate')}
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
          >
            Add New Book
          </button>
        </div>

        {/* Filter Tabs */}
        <div className="border-b border-gray-200 mb-6">
          <nav className="-mb-px flex space-x-8">
            {[
              { key: 'all', label: 'All Books', count: myBooks.length },
              { key: 'available', label: 'Available', count: myBooks.filter(b => b.status === 'available').length },
              { key: 'requested', label: 'Requested', count: myBooks.filter(b => b.status === 'requested').length },
              { key: 'donated', label: 'Donated', count: myBooks.filter(b => b.status === 'donated').length }
            ].map((tab) => (
              <button
                key={tab.key}
                onClick={() => setFilter(tab.key)}
                className={`py-2 px-1 border-b-2 font-medium text-sm ${
                  filter === tab.key
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                {tab.label}
                <span className="ml-2 bg-gray-100 text-gray-900 py-0.5 px-2.5 rounded-full text-xs">
                  {tab.count}
                </span>
              </button>
            ))}
          </nav>
        </div>

        {/* Books Grid */}
        {filteredBooks.length === 0 ? (
          <div className="text-center py-12">
            <div className="text-6xl mb-4">📚</div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">No books found</h3>
            <p className="text-gray-500 mb-6">
              {filter === 'all' 
                ? "You haven't added any books yet."
                : `You don't have any ${filter} books.`
              }
            </p>
            {filter === 'all' && (
              <button
                onClick={() => setCurrentPage('donate')}
                className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
              >
                Add Your First Book
              </button>
            )}
          </div>
        ) : (
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredBooks.map((book) => (
              <div
                key={book.id}
                className="bg-white border border-gray-200 rounded-lg overflow-hidden hover:shadow-lg transition-shadow"
              >
                {/* Book Cover */}
                <div className="h-48 bg-gray-100 flex items-center justify-center">
                  {book.cover_image_url ? (
                    <img
                      src={book.cover_image_url}
                      alt={book.title}
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <div className="text-gray-400 text-center">
                      <div className="text-4xl mb-2">📖</div>
                      <div className="text-sm">No Cover</div>
                    </div>
                  )}
                </div>

                {/* Book Info */}
                <div className="p-4">
                  <h3 className="font-semibold text-lg mb-2 line-clamp-2">{book.title}</h3>
                  <p className="text-gray-600 mb-3">by {book.author}</p>
                  
                  <div className="flex items-center justify-between mb-3">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                      book.condition === 'excellent' ? 'bg-green-100 text-green-800' :
                      book.condition === 'good' ? 'bg-blue-100 text-blue-800' :
                      book.condition === 'fair' ? 'bg-yellow-100 text-yellow-800' :
                      'bg-red-100 text-red-800'
                    }`}>
                      {book.condition}
                    </span>
                    
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(book.status)}`}>
                      {getStatusText(book.status)}
                    </span>
                  </div>

                  <div className="text-xs text-gray-500 mb-4">
                    Added on {new Date(book.created_at).toLocaleDateString()}
                  </div>

                  {/* Action Buttons */}
                  <div className="flex gap-2">
                    <button
                      onClick={() => handleViewBook(book.id)}
                      className="flex-1 flex items-center justify-center gap-1 px-3 py-2 bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200 transition-colors"
                    >
                      <EyeIcon className="h-4 w-4" />
                      View
                    </button>
                    
                    <button
                      onClick={() => handleEditBook(book.id)}
                      className="flex-1 flex items-center justify-center gap-1 px-3 py-2 bg-blue-100 text-blue-700 rounded-md hover:bg-blue-200 transition-colors"
                    >
                      <PencilIcon className="h-4 w-4" />
                      Edit
                    </button>
                    
                    <button
                      onClick={() => handleDeleteBook(book.id)}
                      className="px-3 py-2 bg-red-100 text-red-700 rounded-md hover:bg-red-200 transition-colors"
                    >
                      <TrashIcon className="h-4 w-4" />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Back Button */}
        <div className="mt-8 text-center">
          <button
            onClick={() => setCurrentPage('profile')}
            className="px-4 py-2 bg-gray-600 text-white rounded-md hover:bg-gray-700 transition-colors"
          >
            Back to Profile
          </button>
        </div>
      </div>
    </div>
  );
};

export default MyBooks;
