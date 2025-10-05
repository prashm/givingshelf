import React, { useState, useEffect } from 'react';
import { MagnifyingGlassIcon, MapPinIcon } from '@heroicons/react/24/outline';

const Home = ({ books, searchQuery, setSearchQuery, zipCode, setZipCode, handleSearch, handleBookSelect, currentUser, setCurrentPage }) => {
  const [recentBooks, setRecentBooks] = useState([]);
  const [popularGenres, setPopularGenres] = useState([]);

  useEffect(() => {
    // Simulate fetching recent books and popular genres
    if (books && books.length > 0) {
      setRecentBooks(books.slice(0, 6));
      
      // Calculate popular genres
      const genreCounts = {};
      books.forEach(book => {
        if (book.genre) {
          genreCounts[book.genre] = (genreCounts[book.genre] || 0) + 1;
        }
      });
      
      const sortedGenres = Object.entries(genreCounts)
        .sort(([,a], [,b]) => b - a)
        .slice(0, 5)
        .map(([genre]) => genre);
      
      setPopularGenres(sortedGenres);
    }
  }, [books]);

  const handleGenreClick = (genre) => {
    setSearchQuery(genre);
    handleSearch();
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Hero Section */}
      <div className="bg-gradient-to-r from-blue-600 to-purple-600 text-white">
        <div className="container mx-auto px-4 py-16">
          <div className="text-center max-w-3xl mx-auto">
            <h1 className="text-4xl md:text-6xl font-bold mb-6">
              Share the Joy of Reading
            </h1>
            <p className="text-xl mb-8 text-blue-100">
              Connect with book lovers in your community. Donate, discover, and share your favorite books.
            </p>
            
            {/* Search Bar */}
            <div className="bg-white rounded-lg p-2 shadow-lg max-w-2xl mx-auto">
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
                  className="bg-blue-600 text-white px-6 py-3 rounded-md hover:bg-blue-700 transition-colors"
                >
                  Search
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="container mx-auto px-4 py-12">
        {/* Quick Actions */}
        <div className="grid md:grid-cols-3 gap-6 mb-12">
          <div className="bg-white rounded-lg p-6 shadow-md text-center hover:shadow-lg transition-shadow">
            <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg className="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
              </svg>
            </div>
            <h3 className="text-xl font-semibold mb-2">Donate Books</h3>
            <p className="text-gray-600 mb-4">Share your books with the community</p>
            <button
              onClick={() => setCurrentPage('donate')}
              className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 transition-colors"
            >
              Donate Now
            </button>
          </div>

          <div className="bg-white rounded-lg p-6 shadow-md text-center hover:shadow-lg transition-shadow">
            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg className="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </div>
            <h3 className="text-xl font-semibold mb-2">Browse Books</h3>
            <p className="text-gray-600 mb-4">Discover books in your area</p>
            <button
              onClick={() => setCurrentPage('browse')}
              className="bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 transition-colors"
            >
              Browse
            </button>
          </div>

          <div className="bg-white rounded-lg p-6 shadow-md text-center hover:shadow-lg transition-shadow">
            <div className="w-16 h-16 bg-purple-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg className="w-8 h-8 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
            </div>
            <h3 className="text-xl font-semibold mb-2">Join Community</h3>
            <p className="text-gray-600 mb-4">Connect with fellow book lovers</p>
            <button
              onClick={() => setCurrentPage('profile')}
              className="bg-purple-600 text-white px-4 py-2 rounded-md hover:bg-purple-700 transition-colors"
            >
              Join
            </button>
          </div>
        </div>

        {/* Recent Books */}
        {recentBooks.length > 0 && (
          <div className="mb-12">
            <h2 className="text-2xl font-bold mb-6">Recently Added Books</h2>
            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
              {recentBooks.map((book) => (
                <div
                  key={book.id}
                  className="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow cursor-pointer"
                  onClick={() => handleBookSelect(book)}
                >
                  {book.cover_image_url && (
                    <img
                      src={book.cover_image_url}
                      alt={book.title}
                      className="w-full h-48 object-cover"
                    />
                  )}
                  <div className="p-4">
                    <h3 className="font-semibold text-lg mb-2 line-clamp-2">{book.title}</h3>
                    <p className="text-gray-600 mb-2">by {book.author}</p>
                    <div className="flex items-center justify-between">
                      <span className="text-sm text-gray-500">{book.genre}</span>
                      <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                        book.condition === 'excellent' ? 'bg-green-100 text-green-800' :
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
          </div>
        )}

        {/* Popular Genres */}
        {popularGenres.length > 0 && (
          <div className="mb-12">
            <h2 className="text-2xl font-bold mb-6">Popular Genres</h2>
            <div className="flex flex-wrap gap-3">
              {popularGenres.map((genre) => (
                <button
                  key={genre}
                  onClick={() => handleGenreClick(genre)}
                  className="bg-white px-4 py-2 rounded-full border border-gray-200 hover:border-blue-300 hover:bg-blue-50 transition-colors"
                >
                  {genre}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Community Stats */}
        <div className="bg-white rounded-lg p-8 shadow-md">
          <h2 className="text-2xl font-bold mb-6 text-center">Community Impact</h2>
          <div className="grid md:grid-cols-4 gap-6 text-center">
            <div>
              <div className="text-3xl font-bold text-blue-600 mb-2">
                {books ? books.length : 0}
              </div>
              <div className="text-gray-600">Books Shared</div>
            </div>
            <div>
              <div className="text-3xl font-bold text-green-600 mb-2">
                {books ? Math.floor(books.length * 0.8) : 0}
              </div>
              <div className="text-gray-600">Books Donated</div>
            </div>
            <div>
              <div className="text-3xl font-bold text-purple-600 mb-2">
                {books ? Math.floor(books.length * 0.6) : 0}
              </div>
              <div className="text-gray-600">Books Requested</div>
            </div>
            <div>
              <div className="text-3xl font-bold text-orange-600 mb-2">
                {books ? Math.floor(books.length * 0.4) : 0}
              </div>
              <div className="text-gray-600">Happy Readers</div>
            </div>
          </div>
        </div>

        {/* Call to Action */}
        <div className="text-center mt-12">
          <h2 className="text-3xl font-bold mb-4">Ready to Share Your Books?</h2>
          <p className="text-gray-600 mb-6">
            Find books close to home and build meaningful connections.
          </p>
          <button
            onClick={() => setCurrentPage('donate')}
            className="bg-blue-600 text-white px-8 py-3 rounded-md text-lg font-semibold hover:bg-blue-700 transition-colors"
          >
            Start Donating Today
          </button>
        </div>
      </div>
    </div>
  );
};

export default Home;


