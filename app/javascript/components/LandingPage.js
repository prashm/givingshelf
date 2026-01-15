import React, { useState, useEffect } from 'react';
import { MagnifyingGlassIcon, BookOpenIcon, ChevronDownIcon } from '@heroicons/react/24/outline';
import { ShieldCheckIcon, MapPinIcon, UserIcon } from '@heroicons/react/24/solid';

const LandingPage = ({ setCurrentPage, currentUser, onOpenLoginModal }) => {
  const [offsetY, setOffsetY] = useState(0);

  useEffect(() => {
    const handleScroll = () => setOffsetY(window.scrollY);
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);
  const handleBrowseClick = () => {
    setCurrentPage('browse');
  };

  const handleDonateClick = () => {
    if (currentUser) {
      setCurrentPage('donate');
    } else {
      onOpenLoginModal('donate');
    }
  };

  const handleScrollClick = () => {
    const element = document.getElementById('how-it-works');
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Hero Section */}
      <div
        className="relative overflow-hidden flex flex-col"
        style={{
          minHeight: 'calc(100vh - 80px)', // Account for navbar
          background: 'linear-gradient(135deg, #ecfdf5 0%, #f8fafc 100%)'
        }}
      >
        {/* Floating Book Icons */}


        {/* Single Parallax Icon Background (Tiled Horizontally) */}
        <div
          className="absolute inset-0 z-0 pointer-events-none overflow-hidden"
          style={{
            backgroundImage: `url('/bsc-bg.png')`,
            backgroundPosition: 'center',
            backgroundSize: 'contain',
            backgroundRepeat: 'no-repeat',
            transform: `translateY(${offsetY * 0.5}px)`,
            opacity: 0.15
          }}
        />

        <div className="container mx-auto px-4 py-12 flex-grow flex flex-col relative z-10">
          <div className="flex-grow flex flex-col justify-center w-full items-center max-w-3xl mx-auto text-center">


            {/* Headline */}
            <h1 className="text-4xl md:text-5xl font-bold text-gray-900 mb-6 drop-shadow-lg">
              Share Books Within Your Community
            </h1>

            {/* Subheadline */}
            <p className="text-xl md:text-2xl text-gray-700 mb-12 leading-relaxed drop-shadow-md">
              Connect with neighbors to give and receive books for free. No buying, no selling—just sharing the joy of reading.
            </p>

            {/* Primary Action Buttons */}
            <div className="w-full max-w-2xl flex flex-col sm:flex-row gap-6 justify-center items-center mb-20">
              <button
                onClick={handleBrowseClick}
                className="flex-1 w-full bg-white text-emerald-700 font-semibold py-4 px-8 rounded-lg text-lg hover:bg-gray-50 transition-colors shadow-lg border-2 border-emerald-700 flex items-center justify-center gap-2"
              >
                <MagnifyingGlassIcon className="h-5 w-5" />
                Browse Books
              </button>
              <button
                onClick={handleDonateClick}
                className="flex-1 w-full bg-emerald-700 text-white font-semibold py-4 px-8 rounded-lg text-lg hover:bg-emerald-800 transition-colors shadow-lg border-2 border-white flex items-center justify-center gap-2"
              >
                <BookOpenIcon className="h-5 w-5" />
                Donate Books
              </button>
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
              if (e.key === 'Enter' || e.key === ' ') {
                handleScrollClick();
              }
            }}
          >
            <div className="bg-white rounded-full p-2 shadow-md border border-emerald-100">
              <ChevronDownIcon className="h-6 w-6 text-emerald-700 animate-bounce" />
            </div>
          </div>
        </div>

        {/* Floating Animation Keyframes */}
        <style>{`
          @keyframes float {
            0%, 100% {
              transform: translateY(0px) rotate(0deg);
            }
            50% {
              transform: translateY(-20px) rotate(5deg);
            }
          }
        `}</style>
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
              {/* Looking for Books Card */}
              <div className="bg-white rounded-lg border border-emerald-200 shadow-lg p-8 relative overflow-hidden">
                <div className="absolute top-0 right-0 w-40 h-40 bg-emerald-100 opacity-50" style={{ borderRadius: '0 0 0 100%' }}></div>
                <div className="relative">
                  <div className="flex items-center gap-3 mb-6">
                    <MagnifyingGlassIcon className="h-8 w-8 text-emerald-700" />
                    <h2 className="text-2xl font-bold text-gray-900">Looking for Books?</h2>
                  </div>
                  <div className="space-y-4">
                    <div className="flex items-start gap-4">
                      <div className="flex-shrink-0 w-8 h-8 bg-emerald-700 text-white rounded-full flex items-center justify-center font-semibold">
                        1
                      </div>
                      <div>
                        <h3 className="font-semibold text-gray-900 mb-1">Search Locally</h3>
                        <p className="text-gray-600">Browse books available in your ZIP code or within 10-20 miles</p>
                        <p className="text-gray-500 text-sm mt-2 italic">Your browser may ask for location permission. We only use this information to help you find books in your local area. Your exact location is never stored or shared - we only use it to show you books nearby.</p>
                      </div>
                    </div>
                    <div className="flex items-start gap-4">
                      <div className="flex-shrink-0 w-8 h-8 bg-emerald-700 text-white rounded-full flex items-center justify-center font-semibold">
                        2
                      </div>
                      <div>
                        <h3 className="font-semibold text-gray-900 mb-1">Request a Book</h3>
                        <p className="text-gray-600">Create a free account and connect with the donor through our secure messaging</p>
                      </div>
                    </div>
                    <div className="flex items-start gap-4">
                      <div className="flex-shrink-0 w-8 h-8 bg-emerald-700 text-white rounded-full flex items-center justify-center font-semibold">
                        3
                      </div>
                      <div>
                        <h3 className="font-semibold text-gray-900 mb-1">Pick It Up</h3>
                        <p className="text-gray-600">Arrange a safe, convenient pickup location and time and enjoy your new book</p>
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
                    <h2 className="text-2xl font-bold text-gray-900">Have Books to Share?</h2>
                  </div>
                  <div className="space-y-4">
                    <div className="flex items-start gap-4">
                      <div className="flex-shrink-0 w-8 h-8 bg-blue-700 text-white rounded-full flex items-center justify-center font-semibold">
                        1
                      </div>
                      <div>
                        <h3 className="font-semibold text-gray-900 mb-1">List Your Books</h3>
                        <p className="text-gray-600">Create an account and add photos and descriptions of books you'd like to donate</p>
                      </div>
                    </div>
                    <div className="flex items-start gap-4">
                      <div className="flex-shrink-0 w-8 h-8 bg-blue-700 text-white rounded-full flex items-center justify-center font-semibold">
                        2
                      </div>
                      <div>
                        <h3 className="font-semibold text-gray-900 mb-1">Connect with Readers</h3>
                        <p className="text-gray-600">Receive requests from people in your community who want your books</p>
                      </div>
                    </div>
                    <div className="flex items-start gap-4">
                      <div className="flex-shrink-0 w-8 h-8 bg-blue-700 text-white rounded-full flex items-center justify-center font-semibold">
                        3
                      </div>
                      <div>
                        <h3 className="font-semibold text-gray-900 mb-1">Arrange Pickup</h3>
                        <p className="text-gray-600">Coordinate a safe handoff and make someone's day with a free book</p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Why BookShare Community Section */}
      <div className="min-h-screen flex items-center justify-center bg-emerald-50 py-16" style={{ backgroundImage: 'radial-gradient(circle, rgba(16, 185, 129, 0.1) 1px, transparent 1px)', backgroundSize: '20px 20px' }}>
        <div className="container mx-auto px-4">
          <div className="max-w-4xl mx-auto">
            <h2 className="text-3xl md:text-4xl font-bold text-gray-900 text-center mb-12">
              Why BookShare Community?
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
                <p className="text-gray-600">No hidden costs, no selling. Just neighbors helping neighbors discover great reads.</p>
              </div>

              {/* Local Focus Card */}
              <div className="bg-white rounded-lg shadow-md p-8 text-center">
                <div className="flex justify-center mb-4">
                  <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center">
                    <MapPinIcon className="h-8 w-8 text-blue-600" />
                  </div>
                </div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">Local Focus</h3>
                <p className="text-gray-600">Find books right in your neighborhood. Easy pickups, minimal travel.</p>
              </div>

              {/* Verified Users Card */}
              <div className="bg-white rounded-lg shadow-md p-8 text-center">
                <div className="flex justify-center mb-4">
                  <div className="w-16 h-16 bg-purple-100 rounded-full flex items-center justify-center">
                    <UserIcon className="h-8 w-8 text-purple-600" />
                  </div>
                </div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">Verified Users</h3>
                <p className="text-gray-600">All users are verified for safety. Secure messaging keeps your info private.</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div >
  );
};

export default LandingPage;

