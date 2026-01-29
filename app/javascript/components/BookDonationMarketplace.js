import React, { useState, useEffect } from 'react';
import { useBooks } from '../contexts/BookContext';
import { useAuth } from '../contexts/AuthContext';
import Navbar from './Navbar';
import LandingPage from './LandingPage';
import BookList from './BookList';
import AddBook from './books/AddBook';
import EditBook from './books/EditBook';
import BookDetail from './books/BookDetail';
import BookRequestDetail from './messages/BookRequestDetail';
import MessagesPage from './messages/MessagesPage';
import Profile from './profile/Profile';
import MyBooks from './profile/MyBooks';
import MyRequests from './profile/MyRequests';
import MyGroups from './profile/MyGroups';
import GroupPage from './group/GroupPage';
import WelcomeModal from './WelcomeModal';
import PrivacyPolicyModal from './PrivacyPolicyModal';
import TermsOfServiceModal from './TermsOfServiceModal';
import {
  MagnifyingGlassIcon,
  ArrowUpTrayIcon,
  UserIcon,
  ChatBubbleLeftRightIcon,
  MapPinIcon,
  ShieldCheckIcon
} from '@heroicons/react/24/outline';
import axios from '../lib/axios';
import { parsePageFromPath } from '../lib/textUtils';

// Main App Component
const BookDonationMarketplace = () => {
  const { currentUser, loading: authLoading } = useAuth();
  const { books, fetchBooks, searchBooks, loading } = useBooks();

  // Initialize page state from URL
  const getInitialPage = () => {
    if (typeof window !== 'undefined') {
      const { page } = parsePageFromPath(window.location.pathname);
      return page;
    }
    return 'home';
  };
  const [currentPage, _setPageState] = useState(getInitialPage);
  const [previousPage, setPreviousPage] = useState(null);
  const [searchResults, setSearchResults] = useState([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [zipCode, setZipCode] = useState('');
  const [selectedBook, setSelectedBook] = useState(null);
  const [editingBookId, setEditingBookId] = useState(null);
  const [selectedBookRequestId, setSelectedBookRequestId] = useState(null);
  const [redirectReason, setRedirectReason] = useState(null);
  const [donateInitialTitle, setDonateInitialTitle] = useState(null);
  const [bookDetailSource, setBookDetailSource] = useState(null);
  const [isLoginModalOpen, setIsLoginModalOpen] = useState(false);
  const [pendingNavigation, setPendingNavigation] = useState(null);
  const [zipCodeDetected, setZipCodeDetected] = useState(false);
  const [isPrivacyModalOpen, setIsPrivacyModalOpen] = useState(false);
  const [isTermsModalOpen, setIsTermsModalOpen] = useState(false);
  const [groupShortName, setGroupShortName] = useState(null);

  // Detect route on mount and set group short name if on group page
  useEffect(() => {
    const { groupShortName: shortName } = parsePageFromPath(window.location.pathname);
    if (shortName) {
      setGroupShortName(shortName);
    }
  }, []); // Only run once on mount

  // Sync page state with URL on initial load (in case URL changed before component mounted)
  useEffect(() => {
    const { page: expectedPage, groupShortName: shortName } = parsePageFromPath(window.location.pathname);
    if (shortName) {
      setGroupShortName(shortName);
    }
    if (currentPage !== expectedPage) {
      _setPageState(expectedPage);
    }
  }, []); // Only run once on mount

  // Detect zip code only when on browse page
  useEffect(() => {
    // Only run on browse page
    if (currentPage !== 'browse') return;
    // Don't run until auth check is complete
    if (authLoading) return;
    // Don't run if we've already detected zip code
    if (zipCodeDetected) return;

    const detectZipCode = async () => {
      // First, check if user is signed in and has a zip code
      if (currentUser && currentUser.zip_code) {
        setZipCode(currentUser.zip_code);
        setZipCodeDetected(true);
        // Filter books by zip code
        searchBooks('', currentUser.zip_code);
        return;
      }

      // Only detect from IP if we haven't detected yet and user is not signed in or has no zip
      if (!currentUser || !currentUser.zip_code) {
        // Define helper function for IP-based detection
        const detectZipFromIP = async () => {
          try {
            const response = await axios.get('/api/location/detect_zip', {
              withCredentials: true
            });

            if (response.data.zip_code) {
              setZipCode(response.data.zip_code);
              setZipCodeDetected(true);
              // Filter books by detected zip code
              searchBooks('', response.data.zip_code);
            } else {
              // If zip detection fails, just load all books
              setZipCodeDetected(true); // Mark as detected even if failed, to avoid retrying
              fetchBooks();
            }
          } catch (error) {
            console.error('Error detecting zip code:', error);
            // If detection fails, just load all books
            setZipCodeDetected(true); // Mark as detected even if failed, to avoid retrying
            fetchBooks(); // Load all books even if zip detection fails
          }
        };

        // Try browser geolocation first (works with DevTools simulation)
        if (navigator.geolocation) {
          navigator.geolocation.getCurrentPosition(
            async (position) => {
              const { latitude, longitude } = position.coords;
              try {
                // Use coordinates for reverse geocoding
                const response = await axios.get('/api/location/detect_zip', {
                  params: { latitude, longitude },
                  withCredentials: true
                });

                if (response.data.zip_code) {
                  setZipCode(response.data.zip_code);
                  setZipCodeDetected(true);
                  searchBooks('', response.data.zip_code);
                } else {
                  // Fallback to IP-based detection
                  detectZipFromIP();
                }
              } catch (error) {
                console.error('Error detecting zip code from coordinates:', error);
                // Fallback to IP-based detection
                detectZipFromIP();
              }
            },
            (error) => {
              console.log('Geolocation not available or denied, falling back to IP:', error);
              // Fallback to IP-based detection
              detectZipFromIP();
            },
            { timeout: 5000, maximumAge: 600000 } // Cache for 10 minutes
          );
        } else {
          // Browser geolocation not supported, use IP-based detection
          detectZipFromIP();
        }
      }
    };

    detectZipCode();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentPage, currentUser, authLoading, zipCodeDetected]);

  // Scroll to top when page changes
  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: 'instant' });
  }, [currentPage]);

  // Handle browser history navigation
  useEffect(() => {
    // Set initial state based on URL
    const { page: initialPage, groupShortName: initialShortName } = parsePageFromPath(window.location.pathname);
    if (initialShortName) {
      setGroupShortName(initialShortName);
    }
    window.history.replaceState({ page: initialPage }, '', window.location.pathname);

    const handlePopState = (event) => {
      const state = event.state;
      if (state && state.page) {
        _setPageState(state.page);

        // Restore specific states if present
        if (state.selectedBook) setSelectedBook(state.selectedBook);
        if (state.editingBookId) setEditingBookId(state.editingBookId);
        if (state.bookRequestId) setSelectedBookRequestId(state.bookRequestId);
        if (state.donateInitialTitle) setDonateInitialTitle(state.donateInitialTitle);
        if (state.bookDetailSource) setBookDetailSource(state.bookDetailSource);
        if (state.groupShortName) setGroupShortName(state.groupShortName);
      } else {
        // Read from URL if state is missing
        const { page, groupShortName: shortName } = parsePageFromPath(window.location.pathname);
        _setPageState(page);
        if (shortName) {
          setGroupShortName(shortName);
        }
      }
    };

    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, []);

  // Navigation wrapper to sync with history
  const setCurrentPage = (page, extraState = {}) => {
    // Track previous page before updating
    setPreviousPage(currentPage);

    if (extraState.selectedBook) {
      setSelectedBook(extraState.selectedBook);
    }
    if (extraState.editingBookId) {
      setEditingBookId(extraState.editingBookId);
    }
    if (extraState.bookRequestId) {
      setSelectedBookRequestId(extraState.bookRequestId);
    }
    // Clear donateInitialTitle if navigating to donate page without it, or set it if provided
    if (page === 'donate') {
      if (extraState.donateInitialTitle !== undefined) {
        setDonateInitialTitle(extraState.donateInitialTitle);
      } else {
        setDonateInitialTitle(null);
      }
    }
    // Track book detail source
    if (extraState.bookDetailSource !== undefined) {
      setBookDetailSource(extraState.bookDetailSource);
    }
    // Track group short name for group pages
    if (page === 'groupPage' && extraState.groupShortName) {
      setGroupShortName(extraState.groupShortName);
    }

    _setPageState(page);

    // Update URL based on page
    let url = window.location.pathname;
    if (page === 'browse') {
      url = '/browse';
    } else if (page === 'home') {
      url = '/';
    } else if (page === 'myGroups') {
      url = '/my-groups';
    } else if (page === 'groupPage' && extraState.groupShortName) {
      url = `/g/${extraState.groupShortName}`;
    }
    // Don't update URL if we're on a group page and navigating to another group page
    // (preserve the current URL)

    window.history.pushState({ page, ...extraState }, '', url);
  };

  // Update search results when books change
  useEffect(() => {
    if (Array.isArray(books)) {
      setSearchResults(books);
    }
  }, [books]);

  const handleSearch = (searchRadius = null) => {
    // Use searchBooks from context which handles zip code filtering on backend
    if (zipCode) {
      searchBooks(searchQuery, zipCode, false, searchRadius);
    } else {
      // If no zip code, filter locally
      const query = searchQuery.toLowerCase();
      const results = Array.isArray(books) ? books.filter(book =>
        book.title.toLowerCase().includes(query) ||
        book.author.toLowerCase().includes(query)
      ) : [];
      setSearchResults(results);
    }
  };

  const handleBookSelect = (book, source = 'browse') => {
    setSelectedBook(book);
    setBookDetailSource(source);
    const extraState = { selectedBook: book, bookDetailSource: source };
    // If navigating from a group page, include the group short name
    if (source === 'groupPage' && groupShortName) {
      extraState.groupShortName = groupShortName;
    }
    setCurrentPage('bookDetails', extraState);
  };

  const handleEditBook = (bookId) => {
    setEditingBookId(bookId);
    setCurrentPage('editBook', { editingBookId: bookId });
  };

  const handleDonateBook = (bookData) => {
    // This will be handled by the BookContext
    setCurrentPage('browse');
  };

  const renderPage = () => {
    switch (currentPage) {
      case 'home':
        return <LandingPage
          setCurrentPage={setCurrentPage}
          currentUser={currentUser}
          onOpenLoginModal={handleOpenLoginModal}
        />;
      case 'login':
      case 'signup':
        // Login/signup is handled via modal (useEffect will open modal and redirect to home)
        return <LandingPage
          setCurrentPage={setCurrentPage}
          currentUser={currentUser}
          onOpenLoginModal={handleOpenLoginModal}
        />;
      case 'donate':
        return <AddBook
          setCurrentPage={setCurrentPage}
          setRedirectReason={setRedirectReason}
          initialTitle={donateInitialTitle}
          previousPage={previousPage}
        />;
      case 'editBook':
        return <EditBook
          setCurrentPage={setCurrentPage}
          bookId={editingBookId}
        />;
      case 'bookDetails':
        return <BookDetail
          book={selectedBook}
          setCurrentPage={setCurrentPage}
          currentUser={currentUser}
          onEditBook={handleEditBook}
          onOpenLoginModal={handleOpenLoginModal}
          setRedirectReason={setRedirectReason}
          sourcePage={bookDetailSource}
        />;
      case 'browse':
        return <BookList
          books={searchResults}
          searchQuery={searchQuery}
          setSearchQuery={setSearchQuery}
          zipCode={zipCode}
          setZipCode={setZipCode}
          handleSearch={handleSearch}
          handleBookSelect={handleBookSelect}
          currentUser={currentUser}
          setCurrentPage={setCurrentPage}
          onOpenLoginModal={handleOpenLoginModal}
        />;
      case 'messages':
        return <MessagesPage
          setCurrentPage={setCurrentPage}
          currentUser={currentUser}
        />;
      case 'bookRequestDetails':
        return (
          <BookRequestDetail
            bookRequestId={selectedBookRequestId}
            setCurrentPage={setCurrentPage}
            currentUser={currentUser}
          />
        );
      case 'profile':
        return <Profile
          currentUser={currentUser}
          setCurrentPage={setCurrentPage}
          redirectReason={redirectReason}
          clearRedirectReason={() => setRedirectReason(null)}
        />;
      case 'myBooks':
        return <MyBooks
          currentUser={currentUser}
          setCurrentPage={setCurrentPage}
          onEditBook={handleEditBook}
          onViewBook={(book) => handleBookSelect(book, 'myBooks')}
          fromProfile={previousPage === 'profile'}
        />;
      case 'myRequests':
        return <MyRequests
          currentUser={currentUser}
          setCurrentPage={setCurrentPage}
        />;
      case 'myGroups':
        return <MyGroups
          currentUser={currentUser}
          setCurrentPage={setCurrentPage}
        />;
      case 'groupPage':
        return <GroupPage
          groupShortName={groupShortName}
          searchQuery={searchQuery}
          setSearchQuery={setSearchQuery}
          zipCode={zipCode}
          setZipCode={setZipCode}
          handleSearch={handleSearch}
          handleBookSelect={handleBookSelect}
          currentUser={currentUser}
          setCurrentPage={setCurrentPage}
          onOpenLoginModal={handleOpenLoginModal}
        />;
      default:
        return <LandingPage
          setCurrentPage={setCurrentPage}
          currentUser={currentUser}
          onOpenLoginModal={handleOpenLoginModal}
        />;
    }
  };

  const { logout } = useAuth();

  const handleLoginSuccess = (profileIncomplete) => {
    setIsLoginModalOpen(false);
    // The AuthContext will handle setting the currentUser
    // Check if we need to redirect to profile or pending navigation
    if (profileIncomplete) {
      setCurrentPage('profile');
    } else if (pendingNavigation) {
      const extraState = pendingNavigation === 'bookDetails' ? { selectedBook } : {};
      setCurrentPage(pendingNavigation, extraState);
      setPendingNavigation(null);
    }
  };

  const handleOpenLoginModal = (destinationPage = null) => {
    if (destinationPage) {
      setPendingNavigation(destinationPage);
    }
    setIsLoginModalOpen(true);
  };

  const handleCloseLoginModal = () => {
    setIsLoginModalOpen(false);
    setPendingNavigation(null);
  };

  // Handle login/signup page navigation - open modal and redirect to home
  useEffect(() => {
    if (currentPage === 'login' || currentPage === 'signup') {
      handleOpenLoginModal();
      setCurrentPage('browse');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentPage]);

  const handleLogout = async () => {
    await logout();
    setCurrentPage('home');
  };

  return (
    <div className="flex flex-col min-h-screen">
      <Navbar
        currentUser={currentUser}
        setCurrentPage={setCurrentPage}
        onLoginSuccess={handleLoginSuccess}
        onLogout={handleLogout}
        isLoginModalOpen={isLoginModalOpen}
        onOpenLoginModal={handleOpenLoginModal}
        onCloseLoginModal={handleCloseLoginModal}
      />
      <main className="flex-grow bg-gray-50">
        {renderPage()}
      </main>
      <Footer
        setCurrentPage={setCurrentPage}
        onOpenPrivacyModal={() => setIsPrivacyModalOpen(true)}
        onOpenTermsModal={() => setIsTermsModalOpen(true)}
      />
      <PrivacyPolicyModal
        isOpen={isPrivacyModalOpen}
        onClose={() => setIsPrivacyModalOpen(false)}
      />
      <TermsOfServiceModal
        isOpen={isTermsModalOpen}
        onClose={() => setIsTermsModalOpen(false)}
      />
    </div>
  );
};

// Simple Footer Component
const Footer = ({ setCurrentPage, onOpenPrivacyModal, onOpenTermsModal }) => {
  const meta = (typeof window !== 'undefined' && window.GivingshelfAppMeta) ? window.GivingshelfAppMeta : {};
  const companyName = meta.companyName || 'SimplifAI LLC';
  const appVersion = meta.appVersion || '';
  const copyrightYear = meta.copyrightYear || `${new Date().getFullYear()}`;

  return (
    <footer className="bg-gray-800 text-white py-8">
      <div className="container mx-auto px-4 text-center">
        <div className="flex items-center justify-center mb-4">
          <img src="/bsc-icon.png" alt="GivingShelf Community" className="h-8 w-8 mr-2" />
          <span className="text-xl font-semibold">GivingShelf Community</span>
        </div>
        <p className="text-gray-300 mb-4">
          Connecting book lovers through the joy of sharing literature.
        </p>
        <div className="flex justify-center gap-6 mb-4 text-sm">
          <button
            onClick={onOpenPrivacyModal}
            className="text-gray-300 hover:text-white transition-colors underline"
          >
            Privacy Policy
          </button>
          <button
            onClick={onOpenTermsModal}
            className="text-gray-300 hover:text-white transition-colors underline"
          >
            Terms of Service
          </button>
        </div>
        <div className="text-sm text-gray-400">
          © {copyrightYear} {companyName}. All rights reserved.
        </div>
        <div className="text-xs text-gray-500 mt-2">
          {appVersion ? `Version ${appVersion}` : null}
        </div>
      </div>
    </footer>
  );
};

export default BookDonationMarketplace; 