import React, { useState, useEffect, useCallback, useRef } from 'react';
import { fetchCommunityStats } from '../lib/booksApi';
import { fetchGroupByShortName } from '../lib/communityGroupsApi';
import { useItems } from '../contexts/ItemContext';
import * as Constants from '../lib/constants';
import AvailableItemsSection from './common/AvailableItemsSection';
import PopularGenresSection from './common/PopularGenresSection';
import StatsSection from './common/StatsSection';
import CallToActionSection from './common/CallToActionSection';
import WishlistBookCard from './common/WishlistBookCard';
import SearchSection from './common/SearchSection';
import BrowseSearchWithAutocomplete from './common/BrowseSearchWithAutocomplete';

const getLabels = (itemType) => {
  const isBook = itemType === Constants.ITEM_TYPE_BOOK;
  return {
    heroTitle: isBook ? 'Find Books in Your Community' : 'Find Toys in Your Community',
    availableTitle: isBook ? 'Available Books' : 'Available Toys',
    itemsLabel: isBook ? 'Books' : 'Toys',
    itemLabel: isBook ? 'Book' : 'Toy',
    emptyGlobal: isBook ? 'No books Found' : 'No toys Found',
    emptyGroup: isBook ? 'No books available in this group yet.' : 'No toys available in this group yet.',
    sharedLabel: isBook ? 'Books Shared' : 'Toys Shared',
    donatedLabel: isBook ? 'Books Donated' : 'Toys Donated',
    requestedLabel: isBook ? 'Books Requested' : 'Toys Requested',
    happyLabel: isBook ? 'Happy Readers' : 'Happy Recipients',
    donateCta: isBook ? 'Want to donate books? ' : 'Want to donate toys? ',
    searchLabel: isBook ? 'Book Title or Author' : 'Toy Title or Brand',
    searchPlaceholder: isBook ? 'Search by title or author...' : 'Search by title or brand...',
    ctaTitle: isBook ? 'Ready to Share Your Books?' : 'Ready to Share Your Toys?',
    ctaButton: 'Start Donating Today'
  };
};

const ItemList = ({
  itemType,
  groupShortName,
  items,
  searchQuery,
  setSearchQuery,
  zipCode,
  setZipCode,
  handleSearch,
  handleItemSelect,
  currentUser,
  setCurrentPage,
  onOpenLoginModal,
  setRedirectReason
}) => {
  const { paginationMeta, loadMoreItems, searchItems, loading: itemsLoading } = useItems();
  const [searchRadius, setSearchRadius] = useState('exact');
  const [showRadiusOptions, setShowRadiusOptions] = useState(false);
  const [communityStats, setCommunityStats] = useState({
    items_shared: 0,
    items_donated: 0,
    items_requested: 0,
    happy_users: 0
  });
  const [statsLoading, setStatsLoading] = useState(false);
  const hasLoadedInitialStats = useRef(false);

  const [group, setGroup] = useState(null);
  const [groupLoading, setGroupLoading] = useState(false);
  const [selectedSubGroupId, setSelectedSubGroupId] = useState(null);
  const [impactStats, setImpactStats] = useState({ members: 0, items_shared: 0, items_donated: 0, items_requested: 0 });
  const [impactLoading, setImpactLoading] = useState(false);
  const impactRequestSeq = useRef(0);
  const [selectedWishlistSuggestion, setSelectedWishlistSuggestion] = useState(null);
  const [submittedWishlistQuery, setSubmittedWishlistQuery] = useState('');

  const isGroupBrowse = Boolean(groupShortName);
  const labels = getLabels(itemType);

  const loadCommunityStats = useCallback(async () => {
    if (!zipCode || zipCode.length !== 5) return;
    setStatsLoading(true);
    try {
      const radiusParam = searchRadius === 'exact' ? null : searchRadius;
      const stats = await fetchCommunityStats(zipCode, radiusParam, null, null, itemType);
      setCommunityStats(stats);
    } catch (error) {
      console.error('Failed to load community stats:', error);
    } finally {
      setStatsLoading(false);
    }
  }, [zipCode, searchRadius, itemType]);

  const loadGroup = useCallback(async () => {
    if (!groupShortName) return;
    setGroupLoading(true);
    try {
      const groupData = await fetchGroupByShortName(groupShortName);
      setGroup(groupData);
    } catch (error) {
      console.error('Failed to load group:', error);
      setGroup(null);
    } finally {
      setGroupLoading(false);
    }
  }, [groupShortName]);

  const loadImpactStats = useCallback(async (subGroupIdOverride = undefined) => {
    if (!group) return;
    const requestId = ++impactRequestSeq.current;
    setImpactLoading(true);
    try {
      const subGroupId = subGroupIdOverride === undefined ? selectedSubGroupId : subGroupIdOverride;
      const stats = await fetchCommunityStats(null, null, group.id, subGroupId, itemType);
      if (requestId === impactRequestSeq.current) {
        setImpactStats(stats);
      }
    } catch (error) {
      console.error('Failed to load group stats:', error);
      if (requestId === impactRequestSeq.current && group) {
        setImpactStats((prev) => ({ ...prev, members: group?.member_count ?? prev.members }));
      }
    } finally {
      if (requestId === impactRequestSeq.current) {
        setImpactLoading(false);
      }
    }
  }, [group, selectedSubGroupId, itemType]);

  useEffect(() => {
    if (groupShortName) loadGroup();
  }, [groupShortName, loadGroup]);

  useEffect(() => {
    if (zipCode && zipCode.length === 5 && !hasLoadedInitialStats.current && !isGroupBrowse) {
      hasLoadedInitialStats.current = true;
      loadCommunityStats();
    }
  }, [zipCode, loadCommunityStats, isGroupBrowse]);

  useEffect(() => {
    if (!group || !isGroupBrowse) return;
    searchItems('', zipCode || '', false, null, group.id, null);
    loadImpactStats(null);
  }, [group, isGroupBrowse]);

  const performGroupSearch = (queryOverride = null) => {
    if (!group) return;
    const query = queryOverride !== null ? queryOverride : (searchQuery || '');
    setSubmittedWishlistQuery((query || '').trim());
    searchItems(query, zipCode || '', false, null, group.id, selectedSubGroupId);
    loadImpactStats(selectedSubGroupId);
  };

  const handleGenreClick = (genre) => {
    setSearchQuery(genre);
    if (isGroupBrowse) {
      performGroupSearch(genre);
    } else {
      handleSearch(searchRadius === 'exact' ? null : searchRadius);
    }
  };

  const handleSubGroupChange = (e) => {
    const subGroupId = e.target.value ? parseInt(e.target.value) : null;
    setSelectedSubGroupId(subGroupId);
  };

  const hasValidZipCode = zipCode && zipCode.length === 5;
  const radiusOptions = [
    { value: 'exact', label: 'Exact ZIP code only' },
    { value: '10', label: 'Within 10 miles' },
    { value: '20', label: 'Within 20 miles' }
  ];

  const handleRadiusSelect = (radius) => {
    setSearchRadius(radius);
    setShowRadiusOptions(false);
  };

  const handleSearchWithRadius = () => {
    setSubmittedWishlistQuery((searchQuery || '').trim());
    handleSearch(searchRadius === 'exact' ? null : searchRadius);
    if (zipCode && zipCode.length === 5) loadCommunityStats();
  };

  const zipGroupMembership = Array.isArray(currentUser?.community_groups)
    ? currentUser.community_groups.find((g) => g.short_name === Constants.ZIPCODE_SHORT_NAME)
    : null;
  const groupMembership = (isGroupBrowse && Array.isArray(currentUser?.community_groups))
    ? currentUser.community_groups.find((g) => g.id === group?.id)
    : null;
  const selectedZip = (zipCode || '').trim();
  const membershipZip = (zipGroupMembership?.sub_group?.name || '').trim();
  const wishlistScope = (() => {
    if (!currentUser) return null;
    if (isGroupBrowse) {
      if (!group || !groupMembership) return null;
      if (selectedSubGroupId && groupMembership.sub_group?.id !== selectedSubGroupId) return null;
      return {
        community_group_id: group.id,
        sub_group_id: selectedSubGroupId || null
      };
    }
    if (!zipGroupMembership?.id || !zipGroupMembership?.sub_group?.id) return null;
    if (selectedZip.length !== 5) return null;
    if (membershipZip !== selectedZip) return null;
    return {
      community_group_id: zipGroupMembership.id,
      sub_group_id: zipGroupMembership.sub_group.id
    };
  })();
  const canShowWishlistCard = itemType === Constants.ITEM_TYPE_BOOK
    && (items || []).length === 0
    && !itemsLoading
    && (submittedWishlistQuery || '').trim().length >= 2
    && Boolean(currentUser)
    && Boolean(wishlistScope);

  const getResultsLabel = () => {
    if (!paginationMeta.total || paginationMeta.total === 0) return labels.emptyGlobal;
    const total = paginationMeta.total;
    return total === 1 ? `1 ${labels.itemLabel} Found` : `${total} ${labels.itemsLabel} Found`;
  };

  if (isGroupBrowse && groupLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-emerald-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading group...</p>
        </div>
      </div>
    );
  }

  if (isGroupBrowse && !group) {
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

  const secondaryField = isGroupBrowse
    ? (group?.sub_groups && group.sub_groups.length > 0 ? (
        <>
          <label className="block text-gray-700 mb-2">Sub Group</label>
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
      ) : null)
    : (
      <>
        <label className="block text-gray-700 mb-2">Your ZIP Code</label>
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
            {radiusOptions.map((opt) => (
              <button
                key={opt.value}
                type="button"
                className="w-full text-left px-4 py-3 hover:bg-emerald-50 text-gray-700 border-b border-gray-200 flex items-center justify-between last:border-b-0"
                onClick={() => handleRadiusSelect(opt.value)}
              >
                <span>{opt.label}</span>
                {searchRadius === opt.value && (
                  <svg className="w-5 h-5 text-emerald-600" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd"></path>
                  </svg>
                )}
              </button>
            ))}
          </div>
        )}
      </>
    );

  const searchHandler = isGroupBrowse ? () => performGroupSearch() : handleSearchWithRadius;

  const stats = isGroupBrowse
    ? [
        { key: 'members', label: 'Members', value: impactLoading ? '...' : (impactStats.members ?? group?.member_count ?? 0), valueClassName: 'text-orange-600' },
        { key: 'items_shared', label: labels.sharedLabel, value: impactLoading ? '...' : impactStats.items_shared, valueClassName: 'text-blue-600' },
        { key: 'items_donated', label: labels.donatedLabel, value: impactLoading ? '...' : impactStats.items_donated, valueClassName: 'text-green-600' },
        { key: 'items_requested', label: labels.requestedLabel, value: impactLoading ? '...' : impactStats.items_requested, valueClassName: 'text-purple-600' }
      ]
    : [
        { key: 'items_shared', label: labels.sharedLabel, value: statsLoading ? '...' : communityStats.items_shared, valueClassName: 'text-blue-600' },
        { key: 'items_donated', label: labels.donatedLabel, value: statsLoading ? '...' : communityStats.items_donated, valueClassName: 'text-green-600' },
        { key: 'items_requested', label: labels.requestedLabel, value: statsLoading ? '...' : communityStats.items_requested, valueClassName: 'text-purple-600' },
        ...((!statsLoading && communityStats.happy_users > 0) ? [{ key: 'happy_users', label: labels.happyLabel, value: communityStats.happy_users, valueClassName: 'text-orange-600' }] : [])
      ];

  const resultsLabel = isGroupBrowse
    ? (paginationMeta?.total > 0 ? `${paginationMeta.total} ${labels.itemsLabel} Found` : (itemsLoading ? 'Searching...' : labels.emptyGlobal))
    : getResultsLabel();

  const otherItemName = itemType === Constants.ITEM_TYPE_BOOK ? 'toys' : 'books';
  const otherItemType = itemType === Constants.ITEM_TYPE_BOOK ? Constants.ITEM_TYPE_TOY : Constants.ITEM_TYPE_BOOK;

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="container mx-auto px-4 py-12">
        <div className="bg-white rounded-lg shadow-md p-6 mb-8">
          {isGroupBrowse ? (
            <>
              <div className="flex items-center justify-center gap-3 mb-2">
                {group?.logo_url && (
                  <img src={group.logo_url} alt={group?.name} className="w-12 h-12 rounded-md object-contain border border-gray-200 flex-shrink-0" />
                )}
                <h2 className="text-3xl font-bold text-center">{group?.name}</h2>
              </div>
              {group?.group_description && <p className="text-center text-gray-600 mb-6">{group.group_description}</p>}
            </>
          ) : (
            <h2 className="text-3xl font-bold text-center mb-6">{labels.heroTitle}</h2>
          )}

          {itemType === Constants.ITEM_TYPE_BOOK ? (
            <BrowseSearchWithAutocomplete
              queryLabel={labels.searchLabel}
              queryPlaceholder={labels.searchPlaceholder}
              queryValue={searchQuery}
              onQueryChange={(val) => {
                setSearchQuery(val);
                setSelectedWishlistSuggestion(null);
              }}
              onSuggestionSelect={(suggestion) => setSelectedWishlistSuggestion(suggestion)}
              onSearch={searchHandler}
              submitOnEnter={!isGroupBrowse}
              searchDisabled={!isGroupBrowse && !hasValidZipCode}
              searchLoading={itemsLoading}
              secondaryField={secondaryField}
            />
          ) : (
            <SearchSection
              queryLabel={labels.searchLabel}
              queryPlaceholder={labels.searchPlaceholder}
              queryValue={searchQuery}
              onQueryChange={(val) => setSearchQuery(val)}
              onSearch={searchHandler}
              submitOnEnter={!isGroupBrowse}
              searchDisabled={!isGroupBrowse && !hasValidZipCode}
              searchLoading={itemsLoading}
              secondaryField={secondaryField}
            />
          )}

          {!currentUser && (
            <div className="bg-blue-50 border border-blue-200 rounded-md p-4 mb-6">
              <p className="text-center text-blue-800" onClick={() => onOpenLoginModal('donate')}>
                <strong>{labels.donateCta}</strong>
                <span className="underline cursor-pointer">Create an account</span> to share with the community.
              </p>
            </div>
          )}

          <p className="text-center text-sm text-gray-500 -mt-2 mb-6">
            Looking for {otherItemName} instead?{' '}
            <button
              type="button"
              className="text-emerald-600 hover:text-emerald-700 underline cursor-pointer font-medium"
              onClick={() => isGroupBrowse
                ? setCurrentPage('groupBrowse', { groupShortName, itemType: otherItemType })
                : setCurrentPage(otherItemName)
              }
            >
              Click here
            </button>
          </p>
        </div>

        <AvailableItemsSection
          title={labels.availableTitle}
          books={items || []}
          itemType={itemType}
          resultsLabel={resultsLabel}
          onBookSelect={(item) => handleItemSelect(item, isGroupBrowse ? 'groupPage' : (itemType === Constants.ITEM_TYPE_TOY ? 'toys' : 'books'), itemType)}
          paginationMeta={paginationMeta}
          loadMoreBooks={loadMoreItems}
          loading={itemsLoading}
          emptyMessage={isGroupBrowse ? labels.emptyGroup : labels.emptyGlobal}
        />
        {canShowWishlistCard && (
          <div className="mb-12 flex w-full justify-center">
            <div className="w-full max-w-sm md:max-w-md lg:max-w-[25.5rem]">
              <WishlistBookCard
                searchQuery={submittedWishlistQuery}
                selectedSuggestion={selectedWishlistSuggestion}
                wishlistScope={wishlistScope}
                currentUser={currentUser}
                setCurrentPage={setCurrentPage}
                onOpenLoginModal={onOpenLoginModal}
                setRedirectReason={setRedirectReason}
              />
            </div>
          </div>
        )}

        {itemType === Constants.ITEM_TYPE_BOOK && (
          <PopularGenresSection books={items || []} onGenreClick={handleGenreClick} />
        )}

        <StatsSection
          title="Community Impact"
          columnsClassName={isGroupBrowse ? 'md:grid-cols-4' : (communityStats.happy_users > 0 ? 'md:grid-cols-4' : 'md:grid-cols-3')}
          stats={stats}
        />

        <CallToActionSection
          title={labels.ctaTitle}
          buttonText={labels.ctaButton}
          currentUser={currentUser}
          setCurrentPage={setCurrentPage}
          onOpenLoginModal={onOpenLoginModal}
          donateItemType={itemType}
        />
      </div>
    </div>
  );
};

export default ItemList;
