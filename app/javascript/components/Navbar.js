import React, { useState, useEffect, useRef } from 'react';
import { Bars3Icon, XMarkIcon } from '@heroicons/react/24/outline';
import LoginSignupModal from './auth/LoginSignupModal';
import * as Constants from '../lib/constants';

const Navbar = ({ currentUser, setCurrentPage, currentPage, onLoginSuccess, onLogout, isLoginModalOpen, onOpenLoginModal, onCloseLoginModal }) => {
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

  const handleNavClick = (page, extraState = {}) => {
    setCurrentPage(page, extraState);
    setIsMobileMenuOpen(false);
  };

  const isOnToysPage = currentPage === 'toys' || (typeof window !== 'undefined' && window.location.pathname === '/toys');
  const donateLabel = isOnToysPage ? 'Donate a Toy' : 'Donate a Book';
  const donateExtra = isOnToysPage ? { donateItemType: Constants.ITEM_TYPE_TOY } : { donateItemType: Constants.ITEM_TYPE_BOOK };

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
      <li className="cursor-pointer hover:bg-emerald-700 px-4 py-2 rounded" onClick={() => handleNavClick('donate', donateExtra)}>{donateLabel}</li>
      <li className="cursor-pointer hover:bg-emerald-700 px-4 py-2 rounded" onClick={() => handleNavClick('myBooks')}>My Books</li>
      <li className="cursor-pointer hover:bg-emerald-700 px-4 py-2 rounded" onClick={() => handleNavClick('messages')}>My Requests</li>
      <li className="cursor-pointer hover:bg-emerald-700 px-4 py-2 rounded" onClick={() => handleNavClick('myGroups')}>My Groups</li>
      <li className="cursor-pointer hover:bg-emerald-700 px-4 py-2 rounded" onClick={() => handleNavClick('profile')}>
        {currentUser.first_name || currentUser.email_address || 'Profile'}
      </li>
      <li className="cursor-pointer hover:bg-emerald-700 px-4 py-2 rounded" onClick={handleLogout}>Logout</li>
    </>
  ) : (
    <>
      <li className="cursor-pointer hover:bg-emerald-700 px-4 py-2 rounded" onClick={handleLoginClick}>Login</li>
    </>
  );

  return (
    <>
      <header className="bg-emerald-600 text-white shadow-sd relative h-16 w-full">
        <div className="flex justify-between items-center h-full w-full">
          <div className="flex items-center h-full cursor-pointer" onClick={() => handleNavClick('home')}>
            <div className="bg-white aspect-square flex items-center justify-center p-2">
              <img src="/gs-logo.png" alt="GivingShelf" className="h-full w-48 object-contain" />
            </div>
          </div>

          {/* Desktop Menu */}
          <nav className="hidden md:block mr-4">
            <ul className="flex space-x-6">
              {currentUser ? (
                <>
                  <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('donate', donateExtra)}>{donateLabel}</li>
                  <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('myBooks')}>My Books</li>
                  <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('messages')}>My Requests</li>
                  <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('myGroups')}>My Groups</li>
                  <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('profile')}>
                    Profile
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