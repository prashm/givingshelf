import React, { useState, useEffect, useRef } from 'react';
import { Bars3Icon, XMarkIcon } from '@heroicons/react/24/outline';
import LoginSignupModal from './auth/LoginSignupModal';
import { parsePageFromPath, getGroupPageInfo } from '../lib/textUtils';
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

  const path = typeof window !== 'undefined' ? window.location.pathname : '/';
  const parsed = parsePageFromPath(path);
  const isToysContext = parsed.page === 'toys' || (parsed.page === 'groupBrowse' && parsed.itemType === Constants.ITEM_TYPE_TOY);
  const donateLabel = isToysContext ? 'Donate a Toy' : 'Donate a Book';
  const donateExtra = isToysContext ? { donateItemType: Constants.ITEM_TYPE_TOY } : { donateItemType: Constants.ITEM_TYPE_BOOK };

  const { isGroupPage, groupShortName } = typeof window !== 'undefined' ? getGroupPageInfo() : { isGroupPage: false, groupShortName: null };

  const logoClickTarget = isGroupPage && groupShortName ? () => handleNavClick('groupLanding', { groupShortName }) : () => handleNavClick('home');

  const goToBrowsePage = (itemType) => {
    if (parsed.page === 'groupBrowse' && groupShortName) {
      setCurrentPage('groupBrowse', { groupShortName, itemType });
    } else if (itemType === Constants.ITEM_TYPE_TOY) {
      setCurrentPage('toys');
    } else {
      setCurrentPage('books');
    }
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

  const renderNavItems = (variant) => {
    const isMobile = variant === 'mobile';
    const itemClass = isMobile ? 'cursor-pointer hover:bg-emerald-700 px-4 py-2 rounded' : 'cursor-pointer hover:underline';
    const nav = isMobile ? handleNavClick : (page, extra = {}) => setCurrentPage(page, extra);
    const onLogoutClick = isMobile ? handleLogout : onLogout;

    if (!currentUser) {
      return (
        <li className={itemClass} onClick={handleLoginClick}>Sign In</li>
      );
    }

    return (
      <>
        {parsed.page !== 'groupLanding' && (
          <>
            {isToysContext ? (
              <li className={itemClass} onClick={() => goToBrowsePage(Constants.ITEM_TYPE_TOY)}>Browse Toys</li>
            ) : (
              <li className={itemClass} onClick={() => goToBrowsePage(Constants.ITEM_TYPE_BOOK)}>Browse Books</li>
            )}
            <li className={itemClass} onClick={() => nav('donate', donateExtra)}>{donateLabel}</li>
          </>
        )}
        <li className={itemClass} onClick={() => nav('myItems')}>My Items</li>
        <li className={itemClass} onClick={() => nav('messages')}>My Requests</li>
        <li className={itemClass} onClick={() => nav('myGroups')}>My Groups</li>
        <li className={itemClass} onClick={() => nav('profile')}>Profile</li>
        <li className={itemClass} onClick={onLogoutClick}>Sign Out</li>
      </>
    );
  };

  return (
    <>
      <header className="bg-emerald-600 text-white shadow-sd relative h-16 w-full">
        <div className="flex justify-between items-center h-full w-full">
          <div className="flex items-center h-full cursor-pointer shrink-0" onClick={logoClickTarget}>
            <div className="bg-white h-full flex items-center justify-center px-2 py-1.5 max-h-16">
              <img src="/gs-logo.png" alt="GivingShelf" className="h-full w-auto max-w-[12rem] object-contain object-center" />
            </div>
          </div>

          {/* Desktop Menu */}
          <nav className="hidden md:block mr-4">
            <ul className="flex space-x-6">
              {renderNavItems('desktop')}
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
              {renderNavItems('mobile')}
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