import React, { useState, useEffect } from 'react';
import { MagnifyingGlassIcon, MapPinIcon } from '@heroicons/react/24/outline';
import { fetchCommunityStats } from '../lib/booksApi';

const Home = ({ books, searchQuery, setSearchQuery, zipCode, setZipCode, handleSearch, handleBookSelect, currentUser, setCurrentPage, onOpenLoginModal }) => {
  const [recentBooks, setRecentBooks] = useState([]);
  const [popularGenres, setPopularGenres] = useState([]);
  const [communityStats, setCommunityStats] = useState({
    books_shared: 0,
    books_donated: 0,
    books_requested: 0,
    happy_readers: 0
  });
  const [statsLoading, setStatsLoading] = useState(true);

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

  useEffect(() => {
    const loadCommunityStats = async () => {
      setStatsLoading(true);
      try {
        const stats = await fetchCommunityStats(zipCode);
        setCommunityStats(stats);
      } catch (error) {
        console.error('Failed to load community stats:', error);
        // Keep default values on error
      } finally {
        setStatsLoading(false);
      }
    };

    loadCommunityStats();
  }, [zipCode]);

  const handleGenreClick = (genre) => {
    setSearchQuery(genre);
    handleSearch();
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
                <input className="w-full border rounded-md p-3 pr-10" 
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
            <div className="md:w-1/4">
              <label className="block text-gray-700 mb-2">
                Your ZIP Code
              </label>
              <input className="w-full border rounded-md p-3" 
                placeholder="Enter ZIP code" 
                type="text" 
                value={zipCode}
                onChange={(e) => setZipCode(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
              />
            </div>
            <div className="md:w-1/6 flex items-end">
              <button className="w-full bg-emerald-600 text-white py-3 px-4 rounded-md hover:bg-emerald-700" onClick={handleSearch}>
                Search
              </button>
            </div>
          </div>
          { !currentUser && (
            <div className="bg-blue-50 border border-blue-200 rounded-md p-4 mb-6">
              <p className="text-center text-blue-800"
                onClick={() => {
                  onOpenLoginModal('donate');
                }}
              >
              <strong>Want to donate books?</strong> 
              <span className="underline cursor-pointer"> Create an account</span> to share your books with the community.
              </p>
            </div>
        )}
        </div>


        {/* Recent Books */}
        {recentBooks.length > 0 && (
          <div className="mb-12">
            <h2 className="text-2xl font-bold mb-6">Recently Added Books In Your Community</h2>
            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
              {recentBooks.map((book) => (
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
        { !currentUser && ( 
          <div className="text-center mt-12">
            <h2 className="text-3xl font-bold mb-4">Ready to Share Your Books?</h2>
            <p className="text-gray-600 mb-6">
              Find books close to home and build meaningful connections.
            </p>
            <button
              onClick={() => {                
                  onOpenLoginModal('donate');
              }}
              className="bg-emerald-600 text-white px-8 py-3 rounded-md text-lg font-semibold hover:bg-emerald-700 transition-colors"
            >
              Start Donating Today
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

export default Home;


