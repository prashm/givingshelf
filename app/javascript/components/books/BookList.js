import React, { useState, useEffect } from 'react';
import { MagnifyingGlassIcon, FunnelIcon, MapPinIcon } from '@heroicons/react/24/outline';

const BookList = ({ books, searchQuery, setSearchQuery, zipCode, setZipCode, handleSearch, handleBookSelect, currentUser, setCurrentPage }) => {
  const [filteredBooks, setFilteredBooks] = useState([]);
  const [sortBy, setSortBy] = useState('recent'); // recent, title, author, condition
  const [conditionFilter, setConditionFilter] = useState('all');
  const [genreFilter, setGenreFilter] = useState('all');
  const [showFilters, setShowFilters] = useState(false);

  useEffect(() => {
    if (books) {
      let filtered = [...books];

      // Apply condition filter
      if (conditionFilter !== 'all') {
        filtered = filtered.filter(book => book.condition === conditionFilter);
      }

      // Apply genre filter
      if (genreFilter !== 'all') {
        filtered = filtered.filter(book => book.genre === genreFilter);
      }

      // Apply search filter
      if (searchQuery) {
        const query = searchQuery.toLowerCase();
        filtered = filtered.filter(book => 
          book.title.toLowerCase().includes(query) ||
          book.author.toLowerCase().includes(query) ||
          book.genre.toLowerCase().includes(query)
        );
      }

      // Apply sorting
      filtered.sort((a, b) => {
        switch (sortBy) {
          case 'title':
            return a.title.localeCompare(b.title);
          case 'author':
            return a.author.localeCompare(b.author);
          case 'condition':
            const conditionOrder = { excellent: 1, good: 2, fair: 3, poor: 4 };
            return conditionOrder[a.condition] - conditionOrder[b.condition];
          case 'recent':
          default:
            return new Date(b.created_at) - new Date(a.created_at);
        }
      });

      setFilteredBooks(filtered);
    }
  }, [books, searchQuery, conditionFilter, genreFilter, sortBy]);

  const getUniqueGenres = () => {
    if (!books) return [];
    const genres = books.map(book => book.genre).filter(Boolean);
    return [...new Set(genres)];
  };

  const getConditionColor = (condition) => {
    switch (condition) {
      case 'excellent':
        return 'bg-green-100 text-green-800';
      case 'good':
        return 'bg-blue-100 text-blue-800';
      case 'fair':
        return 'bg-yellow-100 text-yellow-800';
      case 'poor':
        return 'bg-red-100 text-red-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  const handleBookClick = (book) => {
    handleBookSelect(book);
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Search and Filter Header */}
      <div className="bg-white shadow-sm border-b">
        <div className="container mx-auto px-4 py-6">
          {/* Search Bar */}
          <div className="mb-6">
            <div className="bg-white rounded-lg border border-gray-300 p-2 shadow-sm max-w-4xl mx-auto">
              <div className="flex">
                <div className="flex-1 flex items-center px-4">
                  <MagnifyingGlassIcon className="h-5 w-5 text-gray-400 mr-2" />
                  <input
                    type="text"
                    placeholder="Search for books, authors, or genres..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="w-full outline-none text-gray-900"
                    onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
                  />
                </div>
                <div className="flex items-center px-4 border-l border-gray-200">
                  <MapPinIcon className="h-4 w-4 text-gray-400 mr-2" />
                  <input
                    type="text"
                    placeholder="ZIP Code"
                    value={zipCode}
                    onChange={(e) => setZipCode(e.target.value)}
                    className="w-20 outline-none text-gray-900 text-center"
                    onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
                  />
                </div>
                <button
                  onClick={handleSearch}
                  className="bg-emerald-600 text-white px-6 py-3 rounded-md hover:bg-emerald-700 transition-colors"
                >
                  Search
                </button>
              </div>
            </div>
          </div>

          {/* Filters and Sort */}
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div className="flex items-center gap-4">
              <button
                onClick={() => setShowFilters(!showFilters)}
                className="flex items-center gap-2 px-4 py-2 bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200 transition-colors"
              >
                <FunnelIcon className="h-4 w-4" />
                Filters
              </button>
              
              {showFilters && (
                <div className="flex items-center gap-4">
                  {/* Condition Filter */}
                  <select
                    value={conditionFilter}
                    onChange={(e) => setConditionFilter(e.target.value)}
                    className="px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                  >
                    <option value="all">All Conditions</option>
                    <option value="excellent">Excellent</option>
                    <option value="good">Good</option>
                    <option value="fair">Fair</option>
                    <option value="poor">Poor</option>
                  </select>

                  {/* Genre Filter */}
                  <select
                    value={genreFilter}
                    onChange={(e) => setGenreFilter(e.target.value)}
                    className="px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                  >
                    <option value="all">All Genres</option>
                    {getUniqueGenres().map(genre => (
                      <option key={genre} value={genre}>{genre}</option>
                    ))}
                  </select>
                </div>
              )}
            </div>

            {/* Sort Options */}
            <div className="flex items-center gap-2">
              <span className="text-sm text-gray-600">Sort by:</span>
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value)}
                className="px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
              >
                <option value="recent">Most Recent</option>
                <option value="title">Title A-Z</option>
                <option value="author">Author A-Z</option>
                <option value="condition">Best Condition</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      {/* Results Summary */}
      <div className="container mx-auto px-4 py-4">
        <div className="flex items-center justify-between">
          <p className="text-gray-600">
            {filteredBooks.length} book{filteredBooks.length !== 1 ? 's' : ''} found
            {searchQuery && ` for "${searchQuery}"`}
            {zipCode && ` near ${zipCode}`}
          </p>
          
          <button
            onClick={() => setCurrentPage('donate')}
            className="px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700 transition-colors"
          >
            Donate a Book
          </button>
        </div>
      </div>

      {/* Books Grid */}
      <div className="container mx-auto px-4 pb-12">
        {filteredBooks.length === 0 ? (
          <div className="text-center py-16">
            <div className="text-6xl mb-4">🔍</div>
            <h3 className="text-2xl font-bold text-gray-900 mb-2">No books found</h3>
            <p className="text-gray-600 mb-6">
              {searchQuery 
                ? `No books match your search for "${searchQuery}"`
                : 'Try adjusting your filters or search criteria'
              }
            </p>
            <div className="flex gap-4 justify-center">
              <button
                onClick={() => {
                  setSearchQuery('');
                  setConditionFilter('all');
                  setGenreFilter('all');
                }}
                className="px-4 py-2 bg-gray-600 text-white rounded-md hover:bg-gray-700"
              >
                Clear Filters
              </button>
              <button
                onClick={() => setCurrentPage('donate')}
                className="px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700"
              >
                Donate a Book
              </button>
            </div>
          </div>
        ) : (
          <div className="grid md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            {filteredBooks.map((book) => (
              <div
                key={book.id}
                className="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow cursor-pointer transform hover:-translate-y-1 duration-200"
                onClick={() => handleBookClick(book)}
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
                  <h3 className="font-semibold text-lg mb-2 line-clamp-2 text-gray-900">
                    {book.title}
                  </h3>
                  <p className="text-gray-600 mb-3">by {book.author}</p>
                  
                  <div className="flex items-center justify-between mb-3">
                    <span className="text-sm text-gray-500">{book.genre}</span>
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${getConditionColor(book.condition)}`}>
                      {book.condition}
                    </span>
                  </div>

                  {book.summary && (
                    <p className="text-sm text-gray-600 line-clamp-2 mb-3">
                      {book.summary}
                    </p>
                  )}

                  <div className="text-xs text-gray-500">
                    Added {new Date(book.created_at).toLocaleDateString()}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

export default BookList;


