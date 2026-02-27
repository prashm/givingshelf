import React, { useState, useEffect } from 'react';
import { ChevronRightIcon, BookOpenIcon, GiftIcon, MagnifyingGlassIcon } from '@heroicons/react/24/outline';
import { fetchGroupByShortName } from '../../lib/communityGroupsApi';
import { fetchCommunityStats } from '../../lib/booksApi';
import * as Constants from '../../lib/constants';

const CIRCLE_R = 36;
const CIRCLE_CIRCUMFERENCE = 2 * Math.PI * CIRCLE_R;
const STROKE_WIDTH = 10;

const StatsDonut = ({ shared, donated, requested, accentColor = 'emerald', loading }) => {
  const total = shared + donated + requested;
  const sharedPercent = total > 0 ? shared / total : 0;
  const donatedPercent = total > 0 ? donated / total : 0;
  const requestedPercent = total > 0 ? requested / total : 0;
  const sharedDash = sharedPercent * CIRCLE_CIRCUMFERENCE;
  const donatedDash = donatedPercent * CIRCLE_CIRCUMFERENCE;
  const requestedDash = requestedPercent * CIRCLE_CIRCUMFERENCE;

  const sharedColor = accentColor === 'red' ? '#dc2626' : '#059669';
  const donatedColor = '#16a34a';
  const requestedColor = '#9333ea';

  if (loading) {
    return (
      <div className="flex flex-col items-center gap-3 mb-4">
        <div className="w-20 h-20 rounded-full border-2 border-gray-200 animate-pulse" />
        <div className="h-4 w-24 bg-gray-100 rounded animate-pulse" />
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center gap-3 mb-4">
      <svg width={100} height={100} viewBox="0 0 100 100" className="flex-shrink-0">
        <circle
          cx="50"
          cy="50"
          r={CIRCLE_R}
          fill="none"
          stroke={total === 0 ? '#e5e7eb' : sharedColor}
          strokeWidth={STROKE_WIDTH}
          strokeDasharray={total === 0 ? 'none' : `${sharedDash} ${CIRCLE_CIRCUMFERENCE}`}
          strokeDashoffset={0}
          transform="rotate(-90 50 50)"
        />
        {total > 0 && (
          <>
            <circle
              cx="50"
              cy="50"
              r={CIRCLE_R}
              fill="none"
              stroke={donatedColor}
              strokeWidth={STROKE_WIDTH}
              strokeDasharray={`${donatedDash} ${CIRCLE_CIRCUMFERENCE}`}
              strokeDashoffset={-sharedDash}
              transform="rotate(-90 50 50)"
            />
            <circle
              cx="50"
              cy="50"
              r={CIRCLE_R}
              fill="none"
              stroke={requestedColor}
              strokeWidth={STROKE_WIDTH}
              strokeDasharray={`${requestedDash} ${CIRCLE_CIRCUMFERENCE}`}
              strokeDashoffset={-(sharedDash + donatedDash)}
              transform="rotate(-90 50 50)"
            />
          </>
        )}
      </svg>
      <div className="flex flex-wrap justify-center gap-x-4 gap-y-1 text-xs">
        <span className="flex items-center gap-1">
          <span className="w-2 h-2 rounded-full" style={{ backgroundColor: sharedColor }} />
          Shared {shared}
        </span>
        <span className="flex items-center gap-1">
          <span className="w-2 h-2 rounded-full" style={{ backgroundColor: donatedColor }} />
          Donated {donated}
        </span>
        <span className="flex items-center gap-1">
          <span className="w-2 h-2 rounded-full" style={{ backgroundColor: requestedColor }} />
          Requested {requested}
        </span>
      </div>
    </div>
  );
};

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
      <div className="container mx-auto max-w-3xl px-4 py-12">
        <div className="bg-white rounded-lg shadow-md p-6 mb-8">
          <div className="flex items-center justify-center gap-3 mb-2">
            {group.logo_url && (
              <img src={group.logo_url} alt={group.name} className="w-14 h-14 rounded-md object-contain border border-gray-200 flex-shrink-0" />
            )}
            <h2 className="text-3xl font-bold text-center">{group.name}</h2>
          </div>
          {group.group_description && (
            <p className="text-center text-gray-600 mb-2">{group.group_description}</p>
          )}
          <p className="text-center text-gray-500 text-sm mb-8">
            {group.member_count ?? 0} members
          </p>

          <div className="flex flex-col gap-6">
            {/* Books Section */}
            <div className="bg-white rounded-xl border border-gray-200 p-6 flex flex-col">
              <div className="flex flex-col items-center text-center mb-2">
                <div className="w-14 h-14 rounded-full bg-emerald-100 flex items-center justify-center mb-4 border-2 border-emerald-200">
                  <BookOpenIcon className="w-7 h-7 text-emerald-700" />
                </div>
                <h3 className="text-xl font-bold text-gray-900">Books</h3>
              </div>
              <StatsDonut
                shared={booksStats.items_shared}
                donated={booksStats.items_donated}
                requested={booksStats.items_requested}
                accentColor="emerald"
                loading={statsLoading}
              />
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
              <div className="flex flex-col items-center text-center mb-2">
                <div className="w-14 h-14 rounded-full bg-red-100 flex items-center justify-center mb-4 border-2 border-red-200">
                  <GiftIcon className="w-7 h-7 text-red-700" />
                </div>
                <h3 className="text-xl font-bold text-gray-900">Toys</h3>
              </div>
              <StatsDonut
                shared={toysStats.items_shared}
                donated={toysStats.items_donated}
                requested={toysStats.items_requested}
                accentColor="red"
                loading={statsLoading}
              />
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

        <div className="flex flex-col items-center justify-center gap-2 text-center px-2 sm:px-0">
          <p className="text-gray-700 text-base sm:text-lg flex flex-wrap items-center justify-center gap-x-2 gap-y-1">
            <MagnifyingGlassIcon className="w-5 h-5 flex-shrink-0 text-gray-500" aria-hidden />
            <span>Looking for the local community site?</span>
            <span className="inline-flex items-center gap-1">
              Click
              <button
                type="button"
                onClick={() => setCurrentPage('home')}
                className="text-emerald-600 hover:text-emerald-700 font-medium underline cursor-pointer"
              >
                here
              </button>
            </span>
          </p>
        </div>
      </div>
    </div>
  );
};

export default GroupLanding;
