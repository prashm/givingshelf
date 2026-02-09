import React, { useState, useEffect } from 'react';
import { MagnifyingGlassIcon, BookOpenIcon, ChevronDownIcon, ChevronRightIcon, GiftIcon, CubeIcon } from '@heroicons/react/24/outline';
import { ShieldCheckIcon, MapPinIcon, UserIcon } from '@heroicons/react/24/solid';
import * as Constants from '../lib/constants';

const LandingPage = ({ setCurrentPage, currentUser, onOpenLoginModal }) => {
  const [offsetY, setOffsetY] = useState(0);

  useEffect(() => {
    const handleScroll = () => setOffsetY(window.scrollY);
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const handleBrowseBooks = () => setCurrentPage('books');
  const handleDonateBooks = () => {
    if (currentUser) setCurrentPage('donate', { donateItemType: Constants.ITEM_TYPE_BOOK });
    else onOpenLoginModal('donate', { donateItemType: Constants.ITEM_TYPE_BOOK });
  };
  const handleBrowseToys = () => setCurrentPage('toys');
  const handleDonateToys = () => {
    if (currentUser) setCurrentPage('donate', { donateItemType: Constants.ITEM_TYPE_TOY });
    else onOpenLoginModal('donate', { donateItemType: Constants.ITEM_TYPE_TOY });
  };

  const handleScrollClick = () => {
    const element = document.getElementById('how-it-works');
    if (element) element.scrollIntoView({ behavior: 'smooth' });
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Hero Section - keep existing background */}
      <div
        className="relative overflow-hidden flex flex-col"
        style={{
          minHeight: 'calc(100vh - 80px)',
          background: 'linear-gradient(135deg, #ecfdf5 0%, #f8fafc 100%)'
        }}
      >
        {/* Decorative background icons */}
        <div className="absolute inset-0 z-0 pointer-events-none overflow-hidden" aria-hidden>
          <BookOpenIcon className="absolute top-12 left-12 w-16 h-16 md:w-20 md:h-20 text-emerald-300/40" style={{ transform: `translateY(${offsetY * 0.3}px)` }} />
          <CubeIcon className="absolute top-1/2 right-16 w-14 h-14 md:w-16 md:h-16 text-emerald-300/40" style={{ transform: `translateY(${offsetY * 0.2}px)` }} />
          <GiftIcon className="absolute bottom-24 right-20 w-14 h-14 md:w-16 md:h-16 text-emerald-300/40" style={{ transform: `translateY(${-offsetY * 0.2}px)` }} />
        </div>

        <div className="container mx-auto px-4 py-12 flex-grow flex flex-col relative z-10">
          <div className="flex-grow flex flex-col justify-center w-full items-center max-w-4xl mx-auto text-center">
            <h1 className="text-4xl md:text-5xl font-bold text-gray-900 mb-6 drop-shadow-lg">
              Share. Discover. Connect.
            </h1>
            <p className="text-xl md:text-2xl text-gray-700 mb-12 leading-relaxed drop-shadow-md max-w-2xl">
              Give things you no longer need. Find treasures for free. Build community connections through local sharing.
            </p>

            {/* Two cards side-by-side */}
            <div className="w-full grid grid-cols-1 md:grid-cols-2 gap-6 max-w-3xl mb-20">
              {/* Books card */}
              <div className="bg-white rounded-xl shadow-lg p-6 flex flex-col items-center text-center border border-gray-100">
                <div className="w-14 h-14 rounded-full bg-emerald-100 flex items-center justify-center mb-4 border-2 border-emerald-200">
                  <BookOpenIcon className="w-7 h-7 text-emerald-700" />
                </div>
                <h2 className="text-xl font-bold text-gray-900 mb-2">Books</h2>
                <p className="text-gray-600 mb-6 flex-grow">
                  Share your favorite reads and discover new stories from your neighbors
                </p>
                <div className="flex flex-row justify-between items-center w-full mt-auto">
                  <button
                    onClick={handleBrowseBooks}
                    className="text-emerald-600 font-semibold hover:underline flex items-center gap-2 cursor-pointer"
                  >
                    Browse Books
                    <ChevronRightIcon className="w-4 h-4 flex-shrink-0" />
                  </button>
                  <button
                    onClick={handleDonateBooks}
                    className="text-emerald-600 font-semibold hover:underline flex items-center gap-2 cursor-pointer"
                  >
                    Donate Books
                    <ChevronRightIcon className="w-4 h-4 flex-shrink-0" />
                  </button>
                </div>
              </div>

              {/* Toys card */}
              <div className="bg-white rounded-xl shadow-lg p-6 flex flex-col items-center text-center border border-gray-100">
                <div className="w-14 h-14 rounded-full bg-red-100 flex items-center justify-center mb-4 border-2 border-red-200">
                  <GiftIcon className="w-7 h-7 text-red-700" />
                </div>
                <h2 className="text-xl font-bold text-gray-900 mb-2">Toys</h2>
                <p className="text-gray-600 mb-6 flex-grow">
                  Pass on toys your kids outgrew and find new favorites for them
                </p>
                <div className="flex flex-row justify-between items-center w-full mt-auto">
                  <button
                    onClick={handleBrowseToys}
                    className="text-red-600 font-semibold hover:underline flex items-center gap-2 cursor-pointer"
                  >
                    Browse Toys
                    <ChevronRightIcon className="w-4 h-4 flex-shrink-0" />
                  </button>
                  <button
                    onClick={handleDonateToys}
                    className="text-red-600 font-semibold hover:underline flex items-center gap-2 cursor-pointer"
                  >
                    Donate Toys
                    <ChevronRightIcon className="w-4 h-4 flex-shrink-0" />
                  </button>
                </div>
              </div>
            </div>
          </div>

          {/* Scroll indicator */}
          <div
            onClick={handleScrollClick}
            className="flex justify-center pb-8 cursor-pointer hover:scale-110 transition-transform"
            aria-label="Scroll to content"
            role="button"
            tabIndex={0}
            onKeyDown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') handleScrollClick();
            }}
          >
              <ChevronDownIcon className="h-6 w-6 text-emerald-700 animate-bounce" />
          </div>
        </div>
      </div>

      {/* How It Works Section */}
      <div id="how-it-works" className="min-h-screen flex items-center justify-center bg-white py-16">
        <div className="container mx-auto px-4">
          <div className="max-w-4xl mx-auto">
            {/* Section Headline */}
            <h2 className="text-3xl md:text-4xl font-bold text-gray-900 text-center mb-12">
              How It Works
            </h2>
            <div className="space-y-8">
              {/* Looking for Items Card */}
              <div className="bg-white rounded-lg border border-emerald-200 shadow-lg p-8 relative overflow-hidden">
                <div className="absolute top-0 right-0 w-40 h-40 bg-emerald-100 opacity-50" style={{ borderRadius: '0 0 0 100%' }}></div>
                <div className="relative">
                  <div className="flex items-center gap-3 mb-6">
                    <MagnifyingGlassIcon className="h-8 w-8 text-emerald-700" />
                    <h2 className="text-2xl font-bold text-gray-900">Looking for Items?</h2>
                  </div>
                  <div className="space-y-4">
                    <div className="flex items-start gap-4">
                      <div className="flex-shrink-0 w-8 h-8 bg-emerald-700 text-white rounded-full flex items-center justify-center font-semibold">
                        1
                      </div>
                      <div>
                        <h3 className="font-semibold text-gray-900 mb-1">Browse by Category</h3>
                        <p className="text-gray-600">Search books or toys available in your ZIP code or nearby</p>
                        <p className="text-gray-500 text-sm mt-2 italic">Your browser may ask for location permission. We only use this information to help you find books in your local area. Your exact location is never stored or shared - we only use it to show you books nearby.</p>
                      </div>
                    </div>
                    <div className="flex items-start gap-4">
                      <div className="flex-shrink-0 w-8 h-8 bg-emerald-700 text-white rounded-full flex items-center justify-center font-semibold">
                        2
                      </div>
                      <div>
                        <h3 className="font-semibold text-gray-900 mb-1">Request an Item</h3>
                        <p className="text-gray-600">Create a free account and connect with the giver through our secure messaging</p>
                      </div>
                    </div>
                    <div className="flex items-start gap-4">
                      <div className="flex-shrink-0 w-8 h-8 bg-emerald-700 text-white rounded-full flex items-center justify-center font-semibold">
                        3
                      </div>
                      <div>
                        <h3 className="font-semibold text-gray-900 mb-1">Pick It Up</h3>
                        <p className="text-gray-600">Arrange a safe pickup and enjoy your new treasure</p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Have Books to Share Card */}
              <div className="bg-white rounded-lg border border-blue-200 shadow-lg p-8 relative overflow-hidden">
                <div className="absolute top-0 right-0 w-40 h-40 bg-blue-100 opacity-50" style={{ borderRadius: '0 0 0 100%' }}></div>
                <div className="relative">
                  <div className="flex items-center gap-3 mb-6">
                    <BookOpenIcon className="h-8 w-8 text-blue-700" />
                    <h2 className="text-2xl font-bold text-gray-900">Have Things to Give?</h2>
                  </div>
                  <div className="space-y-4">
                    <div className="flex items-start gap-4">
                      <div className="flex-shrink-0 w-8 h-8 bg-blue-700 text-white rounded-full flex items-center justify-center font-semibold">
                        1
                      </div>
                      <div>
                        <h3 className="font-semibold text-gray-900 mb-1">List Your Items</h3>
                        <p className="text-gray-600">Create an account and add photos and descriptions of books or toys you'd like to donate</p>
                      </div>
                    </div>
                    <div className="flex items-start gap-4">
                      <div className="flex-shrink-0 w-8 h-8 bg-blue-700 text-white rounded-full flex items-center justify-center font-semibold">
                        2
                      </div>
                      <div>
                        <h3 className="font-semibold text-gray-900 mb-1">Connect locally</h3>
                        <p className="text-gray-600">Receive requests from people in your community</p>
                      </div>
                    </div>
                    <div className="flex items-start gap-4">
                      <div className="flex-shrink-0 w-8 h-8 bg-blue-700 text-white rounded-full flex items-center justify-center font-semibold">
                        3
                      </div>
                      <div>
                        <h3 className="font-semibold text-gray-900 mb-1">Arrange Handoff</h3>
                        <p className="text-gray-600">Coordinate a safe pickup and make someone's day</p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Why GivingShelf Section */}
      <div className="min-h-screen flex items-center justify-center bg-emerald-50 py-16" style={{ backgroundImage: 'radial-gradient(circle, rgba(16, 185, 129, 0.1) 1px, transparent 1px)', backgroundSize: '20px 20px' }}>
        <div className="container mx-auto px-4">
          <div className="max-w-4xl mx-auto">
            <h2 className="text-3xl md:text-4xl font-bold text-gray-900 text-center mb-12">
              Why GivingShelf?
            </h2>
            <div className="grid md:grid-cols-1 gap-6">
              {/* 100% Free Card */}
              <div className="bg-white rounded-lg shadow-md p-8 text-center">
                <div className="flex justify-center mb-4">
                  <div className="w-16 h-16 bg-emerald-100 rounded-full flex items-center justify-center">
                    <ShieldCheckIcon className="h-8 w-8 text-emerald-600" />
                  </div>
                </div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">100% Free</h3>
                <p className="text-gray-600">No hidden costs, no selling. Just neighbors helping neighbors discover treasures.</p>
              </div>

              {/* Local Focus Card */}
              <div className="bg-white rounded-lg shadow-md p-8 text-center">
                <div className="flex justify-center mb-4">
                  <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center">
                    <MapPinIcon className="h-8 w-8 text-blue-600" />
                  </div>
                </div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">Local Focus</h3>
                <p className="text-gray-600">Find items right in your neighborhood. Easy pickups, minimal travel.</p>
              </div>

              {/* Verified Users Card */}
              <div className="bg-white rounded-lg shadow-md p-8 text-center">
                <div className="flex justify-center mb-4">
                  <div className="w-16 h-16 bg-purple-100 rounded-full flex items-center justify-center">
                    <UserIcon className="h-8 w-8 text-purple-600" />
                  </div>
                </div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">Verified Users</h3>
                <p className="text-gray-600">All users are verified for safety. Secure messaging protects your privacy.</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div >
  );
};

export default LandingPage;

