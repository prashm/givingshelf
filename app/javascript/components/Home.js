import React, { useState, useEffect, useCallback, useRef } from 'react';
import { MagnifyingGlassIcon, MapPinIcon } from '@heroicons/react/24/outline';
import { fetchCommunityStats } from '../lib/booksApi';
import { useBooks } from '../contexts/BookContext';

const Home = ({ books, searchQuery, setSearchQuery, zipCode, setZipCode, handleSearch, handleBookSelect, currentUser, setCurrentPage, onOpenLoginModal }) => {
  const { paginationMeta, loadMoreBooks, loading: booksLoading } = useBooks();
  const [availableBooks, setAvailableBooks] = useState([]);
  const [popularGenres, setPopularGenres] = useState([]);
  const [searchRadius, setSearchRadius] = useState('exact');
  const [showRadiusOptions, setShowRadiusOptions] = useState(false);
  const [communityStats, setCommunityStats] = useState({
    books_shared: 0,
    books_donated: 0,
    books_requested: 0,
    happy_readers: 0
  });
  const [statsLoading, setStatsLoading] = useState(false);
  const hasLoadedInitialStats = useRef(false);

  const loadCommunityStats = useCallback(async () => {
    if (!zipCode || zipCode.length !== 5) {
      return;
    }
    setStatsLoading(true);
    try {
      const radiusParam = searchRadius === 'exact' ? null : searchRadius;
      const stats = await fetchCommunityStats(zipCode, radiusParam);
      setCommunityStats(stats);
    } catch (error) {
      console.error('Failed to load community stats:', error);
      // Keep default values on error
    } finally {
      setStatsLoading(false);
    }
  }, [zipCode, searchRadius]);

  useEffect(() => {
    // Use books directly without slicing since backend handles pagination
    if (books && books.length > 0) {
      setAvailableBooks(books);

      // Calculate popular genres from all available books
      const genreCounts = {};
      books.forEach(book => {
        if (book.genre) {
          genreCounts[book.genre] = (genreCounts[book.genre] || 0) + 1;
        }
      });

      const sortedGenres = Object.entries(genreCounts)
        .sort(([, a], [, b]) => b - a)
        .slice(0, 5)
        .map(([genre]) => genre);

      setPopularGenres(sortedGenres);
    } else {
      setAvailableBooks([]);
      setPopularGenres([]);
    }
  }, [books]);

  // Load stats on initial page load when zip code becomes available
  useEffect(() => {
    if (zipCode && zipCode.length === 5 && !hasLoadedInitialStats.current) {
      hasLoadedInitialStats.current = true;
      loadCommunityStats();
    }
  }, [zipCode, loadCommunityStats]);

  const handleGenreClick = (genre) => {
    setSearchQuery(genre);
    handleSearch(searchRadius === 'exact' ? null : searchRadius);
  };

  const hasValidZipCode = zipCode && zipCode.length === 5;

  const radiusOptions = [
    { value: 'exact', label: 'Exact ZIP code only', display: 'Exact' },
    { value: '10', label: 'Within 10 miles', display: '10mi' },
    { value: '20', label: 'Within 20 miles', display: '20mi' }
  ];

  const selectedRadiusOption = radiusOptions.find(opt => opt.value === searchRadius) || radiusOptions[0];

  const handleRadiusSelect = (radius) => {
    setSearchRadius(radius);
    setShowRadiusOptions(false);
  };

  const handleSearchWithRadius = () => {
    handleSearch(searchRadius === 'exact' ? null : searchRadius);
    // Load stats after search if zip code is present
    if (zipCode && zipCode.length === 5) {
      loadCommunityStats();
    }
  };

  const getResultsLabel = () => {
    if (!paginationMeta.total || paginationMeta.total === 0) return 'No books Found';
    return `${paginationMeta.total === 1 ? '1 Book' : `${paginationMeta.total} Books`} Found`;
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Main Content */}
      <div className="container mx-auto px-4 py-12">
        {/* Hero Section */}
        <div className="bg-white rounded-lg shadow-md p-6 mb-8">
          <h2 className="text-3xl font-bold text-center mb-6">
            Find Books in Your Community
          </h2>
          <div className="flex flex-col md:flex-row gap-4 mb-6">
            <div className="flex-grow">
              <label className="block text-gray-700 mb-2">
                Book Title or Author
              </label>
              <div className="relative">
                <input className="w-full border border-gray-200 rounded-md p-3 pr-10"
                  placeholder="Search by title or author..."
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
                />
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none"
                  stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
                  className="lucide lucide-search absolute right-3 top-3 text-gray-400">
                  <circle cx="11" cy="11" r="8"></circle>
                  <path d="m21 21-4.3-4.3"></path>
                </svg>
              </div>
            </div>
            <div className="md:w-1/4 relative">
              <label className="block text-gray-700 mb-2">
                Your ZIP Code
              </label>
              <div className="relative">
                <div className="flex items-center w-full border border-gray-200 rounded-md bg-white overflow-hidden transition-all focus-within:border-emerald-600 focus-within:ring-4 focus-within:ring-emerald-500/20">
                  <input
                    type="text"
                    className="flex-grow min-w-0 p-3 !outline-none text-gray-700 placeholder-gray-400 !border-none !ring-0 !shadow-none focus:ring-0"
                    style={{ border: 'none', boxShadow: 'none' }}
                    placeholder="Enter ZIP code"
                    value={zipCode}
                    onChange={(e) => setZipCode(e.target.value)}
                    onFocus={() => zipCode && setShowRadiusOptions(true)}
                    onBlur={() => setTimeout(() => setShowRadiusOptions(false), 200)}
                    onKeyPress={(e) => e.key === 'Enter' && hasValidZipCode && handleSearchWithRadius()}
                    maxLength={5}
                  />
                  {zipCode && (
                    <div className="pl-1 mr-3">
                      <button
                        type="button"
                        className="flex items-center gap-1 bg-emerald-50 text-emerald-700 px-3 py-1 rounded text-sm font-medium hover:bg-emerald-100 whitespace-nowrap"
                        onClick={() => setShowRadiusOptions(!showRadiusOptions)}
                      >
                        {searchRadius === 'exact' ? 'Exact' : `${searchRadius}mi`}
                        <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 9l-7 7-7-7"></path>
                        </svg>
                      </button>
                    </div>
                  )}
                </div>
              </div>
              {showRadiusOptions && zipCode && (
                <div className="absolute top-full left-0 right-0 bg-white border border-gray-200 rounded-md shadow-lg z-10" style={{ marginTop: '-1px' }}>
                  <button
                    type="button"
                    className="w-full text-left px-4 py-3 hover:bg-emerald-50 text-gray-700 border-b border-gray-200 flex items-center justify-between"
                    onClick={() => handleRadiusSelect('exact')}
                  >
                    <span>Exact ZIP code only</span>
                    {searchRadius === 'exact' && (
                      <svg className="w-5 h-5 text-emerald-600" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd"></path>
                      </svg>
                    )}
                  </button>
                  <button
                    type="button"
                    className="w-full text-left px-4 py-3 hover:bg-emerald-50 text-gray-700 border-b border-gray-200 flex items-center justify-between"
                    onClick={() => handleRadiusSelect('10')}
                  >
                    <span>Within 10 miles</span>
                    {searchRadius === '10' && (
                      <svg className="w-5 h-5 text-emerald-600" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd"></path>
                      </svg>
                    )}
                  </button>
                  <button
                    type="button"
                    className="w-full text-left px-4 py-3 hover:bg-emerald-50 text-gray-700 flex items-center justify-between"
                    onClick={() => handleRadiusSelect('20')}
                  >
                    <span>Within 20 miles</span>
                    {searchRadius === '20' && (
                      <svg className="w-5 h-5 text-emerald-600" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd"></path>
                      </svg>
                    )}
                  </button>
                </div>
              )}
            </div>
            <div className="md:w-1/6 flex items-end">
              <button
                className={`w-full py-3 px-4 rounded-md transition-colors ${hasValidZipCode
                  ? 'bg-emerald-600 text-white hover:bg-emerald-700 cursor-pointer'
                  : 'bg-gray-300 text-gray-500 cursor-not-allowed'
                  }`}
                onClick={handleSearchWithRadius}
                disabled={!hasValidZipCode}
              >
                Search
              </button>
            </div>
          </div>
          {!currentUser && (
            <div className="bg-blue-50 border border-blue-200 rounded-md p-4 mb-6">
              <p className="text-center text-blue-800"
                onClick={() => {
                  onOpenLoginModal('donate');
                }}
              >
                <strong>Want to donate books? </strong>
                <span className="underline cursor-pointer">Create an account</span> to share your books with the community.
              </p>
            </div>
          )}
        </div>


        {/* Available Books */}
          <div className="mb-12">
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-2xl font-bold">
                Available Books
              </h2>
              <span className="text-gray-600 text-sm">
                {getResultsLabel()}
              </span>
            </div>
            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
              {availableBooks.map((book) => (
                <div
                  key={book.id}
                  className="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow cursor-pointer"
                  onClick={() => handleBookSelect(book)}
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
            {paginationMeta.hasMore && availableBooks.length < paginationMeta.total && (
              <div className="mt-6 text-center">
                <button
                  onClick={loadMoreBooks}
                  disabled={booksLoading}
                  className="border border-blue-200 bg-blue-50 text-blue-800 px-6 py-2 rounded-md enabled:hover:bg-blue-200 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
                >
                  {booksLoading ? 'Loading...' : 'Show more...'}
                </button>
              </div>
            )}
          </div>
 
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
          <div className={`grid gap-6 text-center ${communityStats.happy_readers > 0 ? 'md:grid-cols-4' : 'md:grid-cols-3'}`}>
            <div>
              <div className="text-3xl font-bold text-blue-600 mb-2">
                {statsLoading ? '...' : communityStats.books_shared}
              </div>
              <div className="text-gray-600">Books Shared</div>
            </div>
            <div>
              <div className="text-3xl font-bold text-green-600 mb-2">
                {statsLoading ? '...' : communityStats.books_donated}
              </div>
              <div className="text-gray-600">Books Donated</div>
            </div>
            <div>
              <div className="text-3xl font-bold text-purple-600 mb-2">
                {statsLoading ? '...' : communityStats.books_requested}
              </div>
              <div className="text-gray-600">Books Requested</div>
            </div>
            {(!statsLoading && communityStats.happy_readers > 0) && (
              <div>
                <div className="text-3xl font-bold text-orange-600 mb-2">
                  {communityStats.happy_readers}
                </div>
                <div className="text-gray-600">Happy Readers</div>
              </div>
            )}
          </div>
        </div>

        {/* Call to Action */}
        <div className="text-center mt-12">
          <h2 className="text-3xl font-bold mb-4">Ready to Share Your Books?</h2>
          <button
            onClick={() => {
              if (currentUser) {
                setCurrentPage('donate');
              } else {
                onOpenLoginModal('donate');
              }
            }}
            className="bg-emerald-600 text-white px-8 py-3 rounded-md text-lg font-semibold hover:bg-emerald-700 transition-colors"
          >
            Start Donating Today
          </button>
        </div>
      </div>
    </div>
  );
};

export default Home;


