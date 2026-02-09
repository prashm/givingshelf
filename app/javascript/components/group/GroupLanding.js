import React, { useState, useEffect } from 'react';
import { ChevronRightIcon, BookOpenIcon, GiftIcon } from '@heroicons/react/24/outline';
import { fetchGroupByShortName } from '../../lib/communityGroupsApi';
import { fetchCommunityStats } from '../../lib/booksApi';
import * as Constants from '../../lib/constants';

const GroupLanding = ({ groupShortName, currentUser, setCurrentPage, onOpenLoginModal }) => {
  const [group, setGroup] = useState(null);
  const [loading, setLoading] = useState(true);
  const [booksStats, setBooksStats] = useState({ items_shared: 0, items_donated: 0, items_requested: 0 });
  const [toysStats, setToysStats] = useState({ items_shared: 0, items_donated: 0, items_requested: 0 });
  const [statsLoading, setStatsLoading] = useState(true);

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
    if (groupShortName) loadGroup();
  }, [groupShortName]);

  useEffect(() => {
    if (!group) return;
    setStatsLoading(true);
    Promise.all([
      fetchCommunityStats(null, null, group.id, null, Constants.ITEM_TYPE_BOOK),
      fetchCommunityStats(null, null, group.id, null, Constants.ITEM_TYPE_TOY)
    ]).then(([books, toys]) => {
      setBooksStats(books);
      setToysStats(toys);
    }).catch(console.error).finally(() => setStatsLoading(false));
  }, [group]);

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

  const handleBrowseBooks = () => setCurrentPage('groupBrowse', { groupShortName, itemType: Constants.ITEM_TYPE_BOOK });
  const handleBrowseToys = () => setCurrentPage('groupBrowse', { groupShortName, itemType: Constants.ITEM_TYPE_TOY });
  const handleDonateBooks = () => {
    if (currentUser) setCurrentPage('donate', { donateItemType: Constants.ITEM_TYPE_BOOK });
    else onOpenLoginModal('donate', { donateItemType: Constants.ITEM_TYPE_BOOK });
  };
  const handleDonateToys = () => {
    if (currentUser) setCurrentPage('donate', { donateItemType: Constants.ITEM_TYPE_TOY });
    else onOpenLoginModal('donate', { donateItemType: Constants.ITEM_TYPE_TOY });
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="container mx-auto px-4 py-12">
        <div className="bg-white rounded-lg shadow-md p-6 mb-8">
          <h2 className="text-3xl font-bold text-center mb-2">{group.name}</h2>
          {group.group_description && (
            <p className="text-center text-gray-600 mb-8">{group.group_description}</p>
          )}

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Books Section */}
            <div className="bg-white rounded-xl border border-gray-200 p-6 flex flex-col">
              <div className="w-14 h-14 rounded-full bg-emerald-100 flex items-center justify-center mb-4 border-2 border-emerald-200">
                <BookOpenIcon className="w-7 h-7 text-emerald-700" />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-2">Books</h3>
              <div className="grid grid-cols-3 gap-2 mb-4 text-center text-sm">
                <div>
                  <div className="font-bold text-emerald-600">{statsLoading ? '...' : booksStats.items_shared}</div>
                  <div className="text-gray-500">Shared</div>
                </div>
                <div>
                  <div className="font-bold text-green-600">{statsLoading ? '...' : booksStats.items_donated}</div>
                  <div className="text-gray-500">Donated</div>
                </div>
                <div>
                  <div className="font-bold text-purple-600">{statsLoading ? '...' : booksStats.items_requested}</div>
                  <div className="text-gray-500">Requested</div>
                </div>
              </div>
              <div className="flex flex-row justify-between items-center mt-auto">
                <button onClick={handleBrowseBooks} className="text-emerald-600 font-semibold hover:underline flex items-center gap-2 cursor-pointer">
                  Browse Books <ChevronRightIcon className="w-4 h-4" />
                </button>
                <button onClick={handleDonateBooks} className="text-emerald-600 font-semibold hover:underline flex items-center gap-2 cursor-pointer">
                  Donate Books <ChevronRightIcon className="w-4 h-4" />
                </button>
              </div>
            </div>

            {/* Toys Section */}
            <div className="bg-white rounded-xl border border-gray-200 p-6 flex flex-col">
              <div className="w-14 h-14 rounded-full bg-red-100 flex items-center justify-center mb-4 border-2 border-red-200">
                <GiftIcon className="w-7 h-7 text-red-700" />
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-2">Toys</h3>
              <div className="grid grid-cols-3 gap-2 mb-4 text-center text-sm">
                <div>
                  <div className="font-bold text-red-600">{statsLoading ? '...' : toysStats.items_shared}</div>
                  <div className="text-gray-500">Shared</div>
                </div>
                <div>
                  <div className="font-bold text-green-600">{statsLoading ? '...' : toysStats.items_donated}</div>
                  <div className="text-gray-500">Donated</div>
                </div>
                <div>
                  <div className="font-bold text-purple-600">{statsLoading ? '...' : toysStats.items_requested}</div>
                  <div className="text-gray-500">Requested</div>
                </div>
              </div>
              <div className="flex flex-row justify-between items-center mt-auto">
                <button onClick={handleBrowseToys} className="text-red-600 font-semibold hover:underline flex items-center gap-2 cursor-pointer">
                  Browse Toys <ChevronRightIcon className="w-4 h-4" />
                </button>
                <button onClick={handleDonateToys} className="text-red-600 font-semibold hover:underline flex items-center gap-2 cursor-pointer">
                  Donate Toys <ChevronRightIcon className="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default GroupLanding;
