import React, { useState, useEffect } from 'react';
import { MagnifyingGlassIcon, BookOpenIcon, ChevronDownIcon } from '@heroicons/react/24/outline';
import { ShieldCheckIcon, MapPinIcon, UserIcon } from '@heroicons/react/24/solid';
import axios from '../lib/axios';
import * as Constants from '../lib/constants';

const HERO_IMAGE_BASE = '/images/hero';
// Row 1: hero-book-1, hero-toy-1; Row 2: hero-toy-2, hero-book-2
const HERO_IMAGES = ['hero-book-1.png', 'hero-toy-1.png', 'hero-toy-2.png', 'hero-book-2.png'];

const LandingPage = ({ setCurrentPage, currentUser, onOpenLoginModal }) => {
  const [growthStats, setGrowthStats] = useState([]);

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

  useEffect(() => {
    let isMounted = true;

    const fetchGrowthStats = async () => {
      try {
        const { data } = await axios.get('/growth_stats', { withCredentials: true });
        const stats = (data && Array.isArray(data.stats)) ? data.stats : [];
        if (isMounted) {
          setGrowthStats(stats);
        }
      } catch (_err) {
        // Silently ignore; stats strip simply won't render
      }
    };

    fetchGrowthStats();

    return () => {
      isMounted = false;
    };
  }, []);

  const heroRotations = ['-rotate-2', 'rotate-2', '-rotate-1', 'rotate-1'];

  return (
    <div className="min-h-screen bg-gray-50">
      <style>{`
        @keyframes hero-blob-morph {
          0%, 100% { border-radius: 35% 65% 60% 40% / 55% 45% 55% 45%; }
          25% { border-radius: 50% 50% 40% 60% / 45% 55% 50% 50%; }
          50% { border-radius: 60% 40% 50% 50% / 50% 50% 45% 55%; }
          75% { border-radius: 40% 60% 55% 45% / 55% 45% 50% 50%; }
        }
        @keyframes hero-blob-color {
          0%, 100% { background-color: #a7f3d0; }
          50% { background-color: #fed7aa; }
        }
        .hero-blob {
          animation: hero-blob-morph 10s ease-in-out infinite,
                     hero-blob-color 6s ease-in-out infinite;
        }
      `}</style>
      {/* Hero: left = text + green buttons, right = swatch (morphs) + 4 image cards */}
      <section
        className="relative min-h-[calc(100vh-80px)] flex flex-col"
        style={{
          background: 'linear-gradient(135deg, #ecfdf5 0%, #f8fafc 100%)'
        }}
      >
        <div className="flex-grow flex flex-col md:flex-row md:items-center md:min-h-0 w-full max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-6 pt-4 md:py-16 md:pt-16">
          {/* Left column — text and CTAs, left-aligned on desktop */}
          <div className="flex-1 flex flex-col justify-center order-2 md:order-1 text-center md:text-left md:pr-10 lg:pr-14">
            <h1 className="text-4xl sm:text-5xl font-bold text-gray-900 mb-3 md:mb-5">
              <span className="block">Share and Discover Free Books & Toys Near You.</span>
            </h1>

            <div className="flex flex-col sm:flex-row gap-3 sm:gap-4 justify-center md:justify-start mb-4 md:mb-5">
              <button
                type="button"
                onClick={handleBrowseBooks}
                className="inline-flex items-center justify-center rounded-lg px-6 py-3 bg-emerald-600 text-white font-semibold shadow hover:bg-emerald-700 transition-colors"
              >
                Browse Books
              </button>
              <button
                type="button"
                onClick={handleBrowseToys}
                className="inline-flex items-center justify-center rounded-lg px-6 py-3 bg-white text-emerald-600 font-semibold border-2 border-emerald-600 hover:bg-emerald-50 transition-colors"
              >
                Browse Toys
              </button>
            </div>
            <p className="text-sm text-gray-600">
              <button type="button" onClick={handleDonateBooks} className="text-emerald-600 font-semibold hover:underline cursor-pointer">Donate books</button>
              {' · '}
              <button type="button" onClick={handleDonateToys} className="text-emerald-600 font-semibold hover:underline cursor-pointer">Donate toys</button>
            </p>
          </div>

          {/* Right column — swatch + morphing + 4 image cards; on mobile kept compact so arrow shows without scrolling */}
          <div className="flex-1 flex items-center justify-center order-1 md:order-2 min-h-0 md:min-h-[400px] w-full md:pl-4 relative -mt-2 md:mt-0">
            <div className="relative w-full max-w-lg aspect-[4/3] min-h-[200px] md:min-h-[320px] flex items-center justify-center max-h-[38vh] md:max-h-none">
              {/* Blob: color cycles light green → light orange → light green; shape morphs */}
              <div
                className="hero-blob absolute inset-0 w-full h-full rounded-[35%_65%_60%_40%_/_55%_45%_55%_45%]"
                style={{ backgroundColor: '#a7f3d0' }}
                aria-hidden
              />
              {/* Image cards on top of blob — spread out */}
              <div className="absolute inset-0 flex items-center justify-center p-6 sm:p-8 lg:p-10 z-10">
                <div className="grid grid-cols-2 grid-rows-2 gap-5 sm:gap-6 lg:gap-8 w-full max-w-sm sm:max-w-md lg:max-w-lg max-h-[200px] sm:max-h-[280px] lg:max-h-[320px]">
                  {HERO_IMAGES.map((filename, i) => (
                    <div
                      key={filename}
                      className={`rounded-xl shadow-lg overflow-hidden bg-white ${heroRotations[i % 4]}`}
                    >
                      <img
                        src={`${HERO_IMAGE_BASE}/${filename}`}
                        alt="Featured book or toy"
                        className="w-full h-full min-h-[70px] sm:min-h-[110px] object-cover"
                      />
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Growth stats strip + scroll indicator */}
        {growthStats.length > 0 && (
          <div className="flex justify-center px-4 pt-2">
            <div className="w-full max-w-3xl bg-white/70 backdrop-blur rounded-xl shadow-sm border border-emerald-100 py-5 px-6">
              <div className="grid grid-cols-3 gap-6 text-center">
                {growthStats.map((stat) => (
                  <div key={stat.id || stat.label}>
                    <div className="text-3xl md:text-4xl font-semibold text-gray-900">
                      {stat.value}
                    </div>
                    <div className="mt-2 text-base text-gray-600">
                      {stat.label}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* Scroll indicator — visible on mobile without scrolling */}
        <div
          onClick={handleScrollClick}
          className="flex justify-center pt-2 pb-4 md:pb-6 cursor-pointer hover:scale-110 transition-transform shrink-0"
          aria-label="Scroll to content"
          role="button"
          tabIndex={0}
          onKeyDown={(e) => {
            if (e.key === 'Enter' || e.key === ' ') handleScrollClick();
          }}
        >
          <ChevronDownIcon className="h-6 w-6 text-emerald-700 animate-bounce" />
        </div>
      </section>

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
                        <h3 className="font-semibold text-gray-900 mb-1">Browse by Location</h3>
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

              {/* Have Books to Share Card — orange scheme (Shelf logo color) */}
              <div className="bg-white rounded-lg border shadow-lg p-8 relative overflow-hidden" style={{ borderColor: '#fdba74' }}>
                <div className="absolute top-0 right-0 w-40 h-40 opacity-50" style={{ borderRadius: '0 0 0 100%', backgroundColor: '#ffedd5' }}></div>
                <div className="relative">
                  <div className="flex items-center gap-3 mb-6">
                    <BookOpenIcon className="h-8 w-8" style={{ color: '#F77B24' }} />
                    <h2 className="text-2xl font-bold text-gray-900">Have Things to Give?</h2>
                  </div>
                  <div className="space-y-4">
                    <div className="flex items-start gap-4">
                      <div className="flex-shrink-0 w-8 h-8 text-white rounded-full flex items-center justify-center font-semibold" style={{ backgroundColor: '#F77B24' }}>
                        1
                      </div>
                      <div>
                        <h3 className="font-semibold text-gray-900 mb-1">List Your Items</h3>
                        <p className="text-gray-600">Create an account and add photos and descriptions of books or toys you'd like to donate</p>
                      </div>
                    </div>
                    <div className="flex items-start gap-4">
                      <div className="flex-shrink-0 w-8 h-8 text-white rounded-full flex items-center justify-center font-semibold" style={{ backgroundColor: '#F77B24' }}>
                        2
                      </div>
                      <div>
                        <h3 className="font-semibold text-gray-900 mb-1">Connect locally</h3>
                        <p className="text-gray-600">Receive requests from people in your community</p>
                      </div>
                    </div>
                    <div className="flex items-start gap-4">
                      <div className="flex-shrink-0 w-8 h-8 text-white rounded-full flex items-center justify-center font-semibold" style={{ backgroundColor: '#F77B24' }}>
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
                <p className="text-gray-600">No hidden costs, no selling. Just neighbors helping neighbors discover books and toys.</p>
              </div>

              {/* Local Focus Card */}
              <div className="bg-white rounded-lg shadow-md p-8 text-center">
                <div className="flex justify-center mb-4">
                  <div className="w-16 h-16 rounded-full flex items-center justify-center" style={{ backgroundColor: '#ffedd5' }}>
                    <MapPinIcon className="h-8 w-8" style={{ color: '#F77B24' }} />
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
                <p className="text-gray-600">Every user signs in with a verified email. Trust scores reflect profile completeness and optional address validation. Secure messaging protects your privacy.</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div >
  );
};

export default LandingPage;

