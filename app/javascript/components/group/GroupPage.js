import React, { useState, useEffect } from 'react';
import { fetchGroupByShortName } from '../../lib/communityGroupsApi';
import { useBooks } from '../../contexts/BookContext';

const GroupPage = ({ groupShortName, searchQuery, setSearchQuery, zipCode, setZipCode, handleSearch, handleBookSelect, currentUser, setCurrentPage, onOpenLoginModal }) => {
  const { books, searchBooks, paginationMeta, loadMoreBooks, loading: booksLoading } = useBooks();
  const [group, setGroup] = useState(null);
  const [loading, setLoading] = useState(true);
  const [selectedSubGroupId, setSelectedSubGroupId] = useState(null);
  const [availableBooks, setAvailableBooks] = useState([]);

  useEffect(() => {
    const loadGroup = async () => {
      setLoading(true);
      try {
        const groupData = await fetchGroupByShortName(groupShortName);
        setGroup(groupData);
      } catch (error) {
        console.error('Failed to load group:', error);
        setGroup(null);
      } finally {
        setLoading(false);
      }
    };

    if (groupShortName) {
      loadGroup();
    }
  }, [groupShortName]);

  // Search books when group is loaded or search parameters change
  useEffect(() => {
    if (!group) {
      return;
    }
    
    // searchBooks signature: (query, zipCode, append, radius, communityGroupId, subGroupId)
    searchBooks(searchQuery || '', zipCode || '', false, null, group.id, selectedSubGroupId);
  }, [group, searchQuery, zipCode, selectedSubGroupId, searchBooks]);

  useEffect(() => {
    if (books && books.length > 0) {
      setAvailableBooks(books);
    } else {
      setAvailableBooks([]);
    }
  }, [books]);

  const handleGenreClick = (genre) => {
    setSearchQuery(genre);
    handleSearch();
  };

  const handleSubGroupChange = (e) => {
    const subGroupId = e.target.value ? parseInt(e.target.value) : null;
    setSelectedSubGroupId(subGroupId);
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-emerald-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading group...</p>
        </div>
      </div>
    );
  }

  if (!group) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-800 mb-4">Group Not Found</h1>
          <p className="text-gray-600 mb-4">The group you're looking for doesn't exist.</p>
          <button
            onClick={() => setCurrentPage('home')}
            className="bg-emerald-600 text-white px-6 py-2 rounded-md hover:bg-emerald-700"
          >
            Go Home
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Main Content */}
      <div className="container mx-auto px-4 py-12">
        {/* Group Header */}
        <div className="bg-white rounded-lg shadow-md p-6 mb-8">
          <h2 className="text-3xl font-bold text-center mb-2">
            {group.name}
          </h2>
          {group.group_type && (
            <p className="text-center text-gray-600 mb-6">Find Books In Your {group.group_type} Community</p>
          )}
          
          {/* Search Section */}
          <div className="flex flex-col md:flex-row gap-4 mb-6">
            <div className="flex-grow">
              <label className="block text-gray-700 mb-2">
                Book Title or Author
              </label>
              <div className="relative">
                <input className="w-full border rounded-md p-3 pr-10" 
                  placeholder="Search by title or author..." 
                  type="text" 
                  value={searchQuery || ''}
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
            
            {/* Sub Group Filter */}
            {group.sub_groups && group.sub_groups.length > 0 && (
              <div className="md:w-1/4">
                <label className="block text-gray-700 mb-2">
                  Sub Group
                </label>
                <select 
                  className="w-full border rounded-md p-3"
                  value={selectedSubGroupId || ''}
                  onChange={handleSubGroupChange}
                >
                  <option value="">All {group.group_type || 'Sub Group'}s</option>
                  {group.sub_groups.map((sg) => (
                    <option key={sg.id} value={sg.id}>{sg.name}</option>
                  ))}
                </select>
              </div>
            )}
            
            <div className="md:w-1/6 flex items-end">
              <button className="w-full bg-emerald-600 text-white py-3 px-4 rounded-md hover:bg-emerald-700" onClick={handleSearch}>
                Search
              </button>
            </div>
          </div>
        </div>

        {/* Available Books */}
        {availableBooks.length > 0 && (
          <div className="mb-12">
            <h2 className="text-2xl font-bold mb-6">
              {paginationMeta.total > 0 ? `${paginationMeta.total} Available Books` : 'Available Books'}
            </h2>
            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
              {availableBooks.map((book) => (
                <div
                  key={book.id}
                  className="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow cursor-pointer"
                  onClick={() => handleBookSelect(book, 'groupPage')}
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
            {paginationMeta.hasMore && availableBooks.length < paginationMeta.total && (
              <div className="mt-6 text-center">
                <button
                  onClick={loadMoreBooks}
                  disabled={booksLoading}
                  className="bg-emerald-600 text-white px-6 py-2 rounded-md hover:bg-emerald-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
                >
                  {booksLoading ? 'Loading...' : 'Show more...'}
                </button>
              </div>
            )}
          </div>
        )}

        {availableBooks.length === 0 && !booksLoading && (
          <div className="text-center py-12">
            <p className="text-gray-600 text-lg">No books available in this group yet.</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default GroupPage;

