import React, { useState, useEffect, useRef } from 'react';
import { fetchGroupByShortName } from '../../lib/communityGroupsApi';
import { fetchCommunityStats } from '../../lib/booksApi';
import { useBooks } from '../../contexts/BookContext';
import AvailableItemsSection from '../common/AvailableItemsSection';
import PopularGenresSection from '../common/PopularGenresSection';
import StatsSection from '../common/StatsSection';
import CallToActionSection from '../common/CallToActionSection';
import SearchSection from '../common/SearchSection';

const GroupPage = ({ groupShortName, searchQuery, setSearchQuery, zipCode, setZipCode, handleSearch, handleBookSelect, currentUser, setCurrentPage, onOpenLoginModal }) => {
  const { books, searchBooks, paginationMeta, loadMoreBooks, loading: booksLoading } = useBooks();
  const [group, setGroup] = useState(null);
  const [loading, setLoading] = useState(true);
  const [selectedSubGroupId, setSelectedSubGroupId] = useState(null);
  const [impactStats, setImpactStats] = useState({
    members: 0,
    books_shared: 0,
    books_donated: 0,
    books_requested: 0
  });
  const [impactLoading, setImpactLoading] = useState(false);
  const impactRequestSeq = useRef(0);

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

  const loadImpactStats = async (subGroupIdOverride = undefined) => {
    if (!group) return;
    const requestId = ++impactRequestSeq.current;
    setImpactLoading(true);
    try {
      const subGroupId = subGroupIdOverride === undefined ? selectedSubGroupId : subGroupIdOverride;
      const stats = await fetchCommunityStats(null, null, group.id, subGroupId);
      // Guard against out-of-order responses (e.g., switching sub-groups quickly)
      if (requestId === impactRequestSeq.current) {
        setImpactStats(stats);
      }
    } catch (error) {
      console.error('Failed to load group stats:', error);
      if (requestId === impactRequestSeq.current) {
        setImpactStats((prev) => ({
          ...prev,
          members: group?.member_count ?? prev.members
        }));
      }
    } finally {
      if (requestId === impactRequestSeq.current) {
        setImpactLoading(false);
      }
    }
  };

  // Initial load: fetch group books once group is available.
  // Subsequent searches should only happen via explicit user actions (clicking buttons).
  useEffect(() => {
    if (!group) {
      return;
    }
    // searchBooks signature: (query, zipCode, append, radius, communityGroupId, subGroupId)
    searchBooks('', zipCode || '', false, null, group.id, null);
    // Stats should load on page load (unfiltered / "All" sub group).
    loadImpactStats(null);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [group, searchBooks]);

  const performGroupSearch = (queryOverride = null) => {
    if (!group) return;
    const query = queryOverride !== null ? queryOverride : (searchQuery || '');
    // searchBooks signature: (query, zipCode, append, radius, communityGroupId, subGroupId)
    searchBooks(query, zipCode || '', false, null, group.id, selectedSubGroupId);
    loadImpactStats(selectedSubGroupId);
  };

  const handleGenreClick = (genre) => {
    setSearchQuery(genre);
    // Do not submit until Search button is clicked
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
          {group.group_description && (
            <p className="text-center text-gray-600 mb-6">{group.group_description}</p>
          )}
          
          {/* Search Section */}
          <SearchSection
            queryValue={searchQuery || ''}
            onQueryChange={(val) => setSearchQuery(val)}
            onSearch={() => performGroupSearch()}
            submitOnEnter={false}
            searchDisabled={false}
            secondaryField={
              (group.sub_groups && group.sub_groups.length > 0) ? (
                <>
                  <label className="block text-gray-700 mb-2">
                    Sub Group
                  </label>
                  <select
                    className="w-full border border-gray-200 rounded-md p-3 bg-white"
                    value={selectedSubGroupId || ''}
                    onChange={handleSubGroupChange}
                  >
                    <option value="">All</option>
                    {group.sub_groups.slice().sort((a, b) => a.name.localeCompare(b.name)).map((sg) => (
                      <option key={sg.id} value={sg.id}>{sg.name}</option>
                    ))}
                  </select>
                </>
              ) : null
            }
          />

          {!currentUser && (
            <div className="bg-blue-50 border border-blue-200 rounded-md p-4">
              <p
                className="text-center text-blue-800"
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
        <AvailableItemsSection
          title="Available Books"
          books={books || []}
          resultsLabel={paginationMeta?.total > 0 ? `${paginationMeta.total} Books Found` : (booksLoading ? 'Searching...' : 'No books Found')}
          onBookSelect={(book) => handleBookSelect(book, 'groupPage')}
          paginationMeta={paginationMeta}
          loadMoreBooks={loadMoreBooks}
          loading={booksLoading}
          emptyMessage="No books available in this group yet."
        />

        {/* Popular Genres */}
        <PopularGenresSection
          books={books || []}
          onGenreClick={handleGenreClick}
        />

        {/* Community Stats */}
        <StatsSection
          title="Community Impact"
          columnsClassName="md:grid-cols-4"
          stats={[
            { key: 'members', label: 'Members', value: impactLoading ? '...' : (impactStats.members ?? group.member_count ?? 0), valueClassName: 'text-orange-600' },
            { key: 'books_shared', label: 'Books Shared', value: impactLoading ? '...' : impactStats.books_shared, valueClassName: 'text-blue-600' },
            { key: 'books_donated', label: 'Books Donated', value: impactLoading ? '...' : impactStats.books_donated, valueClassName: 'text-green-600' },
            { key: 'books_requested', label: 'Books Requested', value: impactLoading ? '...' : impactStats.books_requested, valueClassName: 'text-purple-600' }
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

export default GroupPage;

