import React, { useState, useEffect, useCallback, useRef } from 'react';
import { fetchCommunityStats } from '../lib/booksApi';
import { useBooks } from '../contexts/BookContext';
import AvailableBooksSection from './common/AvailableBooksSection';
import PopularGenresSection from './common/PopularGenresSection';
import StatsSection from './common/StatsSection';
import CallToActionSection from './common/CallToActionSection';
import SearchSection from './common/SearchSection';

const BookList = ({ books, searchQuery, setSearchQuery, zipCode, setZipCode, handleSearch, handleBookSelect, currentUser, setCurrentPage, onOpenLoginModal }) => {
  const { paginationMeta, loadMoreBooks, loading: booksLoading } = useBooks();
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
          <SearchSection
            queryValue={searchQuery}
            onQueryChange={(val) => setSearchQuery(val)}
            onSearch={handleSearchWithRadius}
            submitOnEnter={true}
            searchDisabled={!hasValidZipCode}
            secondaryField={
              <>
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
                      onKeyDown={(e) => e.key === 'Enter' && hasValidZipCode && handleSearchWithRadius()}
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
              </>
            }
          />
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
        <AvailableBooksSection
          title="Available Books"
          books={books || []}
          resultsLabel={getResultsLabel()}
          onBookSelect={(book) => handleBookSelect(book)}
          paginationMeta={paginationMeta}
          loadMoreBooks={loadMoreBooks}
          loading={booksLoading}
          emptyMessage="No books Found"
        />
 
        {/* Popular Genres */}
        <PopularGenresSection
          books={books || []}
          onGenreClick={handleGenreClick}
        />

        {/* Community Stats */}
        <StatsSection
          title="Community Impact"
          columnsClassName={communityStats.happy_readers > 0 ? 'md:grid-cols-4' : 'md:grid-cols-3'}
          stats={[
            { key: 'books_shared', label: 'Books Shared', value: statsLoading ? '...' : communityStats.books_shared, valueClassName: 'text-blue-600' },
            { key: 'books_donated', label: 'Books Donated', value: statsLoading ? '...' : communityStats.books_donated, valueClassName: 'text-green-600' },
            { key: 'books_requested', label: 'Books Requested', value: statsLoading ? '...' : communityStats.books_requested, valueClassName: 'text-purple-600' },
            ...((!statsLoading && communityStats.happy_readers > 0) ? [{ key: 'happy_readers', label: 'Happy Readers', value: communityStats.happy_readers, valueClassName: 'text-orange-600' }] : [])
          ]}
        />

        {/* Call to Action */}
        <CallToActionSection
          currentUser={currentUser}
          setCurrentPage={setCurrentPage}
          onOpenLoginModal={onOpenLoginModal}
        />
      </div>
    </div>
  );
};

export default BookList;

