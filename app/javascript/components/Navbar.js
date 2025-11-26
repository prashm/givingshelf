import React, { useState, useEffect, useRef } from 'react';
import { Bars3Icon, XMarkIcon } from '@heroicons/react/24/outline';
import LoginSignupModal from './auth/LoginSignupModal';

const Navbar = ({ currentUser, setCurrentPage, onLoginSuccess, onLogout, isLoginModalOpen, onOpenLoginModal, onCloseLoginModal }) => {
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const menuRef = useRef(null);

  const handleLoginClick = (e) => {
    e.preventDefault();
    e.stopPropagation();
    onOpenLoginModal();
    setIsMobileMenuOpen(false);
  };

  const handleLoginSuccess = (profileIncomplete) => {
    onLoginSuccess(profileIncomplete);
  };

  const handleNavClick = (page) => {
    setCurrentPage(page);
    setIsMobileMenuOpen(false);
  };

  const handleLogout = () => {
    onLogout();
    setIsMobileMenuOpen(false);
  };

  // Close mobile menu when clicking outside
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (menuRef.current && !menuRef.current.contains(event.target)) {
        setIsMobileMenuOpen(false);
      }
    };

    if (isMobileMenuOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [isMobileMenuOpen]);

  const menuItems = currentUser ? (
    <>
      <li className="cursor-pointer hover:bg-emerald-700 px-4 py-2 rounded" onClick={() => handleNavClick('home')}>Browse</li>
      <li className="cursor-pointer hover:bg-emerald-700 px-4 py-2 rounded" onClick={() => handleNavClick('donate')}>Donate a Book</li>
      <li className="cursor-pointer hover:bg-emerald-700 px-4 py-2 rounded" onClick={() => handleNavClick('messages')}>Messages</li>
      <li className="cursor-pointer hover:bg-emerald-700 px-4 py-2 rounded" onClick={() => handleNavClick('profile')}>
        {currentUser.first_name || currentUser.email_address || 'Profile'}
      </li>
      <li className="cursor-pointer hover:bg-emerald-700 px-4 py-2 rounded" onClick={handleLogout}>Logout</li>
    </>
  ) : (
    <>
      <li className="cursor-pointer hover:bg-emerald-700 px-4 py-2 rounded" onClick={() => handleNavClick('home')}>Browse</li>
      <li className="cursor-pointer hover:bg-emerald-700 px-4 py-2 rounded" onClick={handleLoginClick}>Login</li>
    </>
  );

  return (
    <>
      <header className="bg-emerald-600 text-white p-4 shadow-sd relative">
        <div className="mx-auto flex justify-between items-center">
          <div className="flex items-center space-x-2 cursor-pointer" onClick={() => handleNavClick('home')}>
            <img src="/bsc-icon.png" alt="BookShare Community" className="h-8 w-8" />
            <h1 className="text-xl md:text-2xl font-bold">BookShare Community</h1>
          </div>
          
          {/* Desktop Menu */}
          <nav className="hidden md:block">
            <ul className="flex space-x-6">
              <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('home')}>Browse</li>
              { currentUser ? ( 
                <>
                  <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('donate')}>Donate a Book</li>
                  <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('messages')}>Messages</li>
                  <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('profile')}>
                    {currentUser.first_name || currentUser.email_address || 'Profile'}
                  </li>
                  <li className="cursor-pointer hover:underline" onClick={onLogout}>Logout</li>
                </>
              ) : (
                <>
                  <li className="cursor-pointer hover:underline" onClick={handleLoginClick}>Login</li>
                </>
              )}
            </ul>
          </nav>

          {/* Mobile Hamburger Button */}
          <button
            className="md:hidden p-2 rounded-md hover:bg-emerald-700 transition-colors"
            onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
            aria-label="Toggle menu"
          >
            {isMobileMenuOpen ? (
              <XMarkIcon className="h-6 w-6" />
            ) : (
              <Bars3Icon className="h-6 w-6" />
            )}
          </button>
        </div>

        {/* Mobile Menu Dropdown */}
        {isMobileMenuOpen && (
          <nav 
            ref={menuRef}
            className="md:hidden absolute top-full left-0 right-0 bg-emerald-600 shadow-lg z-50"
          >
            <ul className="flex flex-col py-2">
              {menuItems}
            </ul>
          </nav>
        )}
      </header>
      {isLoginModalOpen && (
        <LoginSignupModal 
          isOpen={isLoginModalOpen}
          onClose={onCloseLoginModal}
          onSuccess={handleLoginSuccess}
        />
      )}
    </>
  );
};

export default Navbar; 