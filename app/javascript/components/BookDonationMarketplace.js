import React, { useState, useEffect } from 'react';
import { useBooks } from '../contexts/BookContext';
import { useAuth } from '../contexts/AuthContext';
import Navbar from './Navbar';
import Home from './Home';
import AddBook from './books/AddBook';
import EditBook from './books/EditBook';
import BookList from './books/BookList';
import BookDetail from './books/BookDetail';
import BookRequestDetail from './messages/BookRequestDetail';
import MessagesPage from './messages/MessagesPage';
import Profile from './profile/Profile';
import MyBooks from './profile/MyBooks';
import MyRequests from './profile/MyRequests';
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
import { COMPANY, VERSION } from '../lib/version';

// Main App Component
const BookDonationMarketplace = () => {
  const { currentUser, loading: authLoading } = useAuth();
  const { books, fetchBooks, searchBooks, loading } = useBooks();
  const [currentPage, _setPageState] = useState('home');
  const [previousPage, setPreviousPage] = useState(null);
  const [searchResults, setSearchResults] = useState([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [zipCode, setZipCode] = useState('');
  const [selectedBook, setSelectedBook] = useState(null);
  const [editingBookId, setEditingBookId] = useState(null);
  const [selectedBookRequestId, setSelectedBookRequestId] = useState(null);
  const [redirectReason, setRedirectReason] = useState(null);
  const [isLoginModalOpen, setIsLoginModalOpen] = useState(false);
  const [pendingNavigation, setPendingNavigation] = useState(null);
  const [zipCodeDetected, setZipCodeDetected] = useState(false);
  const [isWelcomeModalOpen, setIsWelcomeModalOpen] = useState(false);
  const [isPrivacyModalOpen, setIsPrivacyModalOpen] = useState(false);
  const [isTermsModalOpen, setIsTermsModalOpen] = useState(false);
  
  // Detect zip code on mount and when user logs in
  useEffect(() => {
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
  }, [currentUser, authLoading, zipCodeDetected]);

  // Handle browser history navigation
  useEffect(() => {
    // Set initial state
    window.history.replaceState({ page: 'home' }, '', window.location.pathname);

    const handlePopState = (event) => {
      const state = event.state;
      if (state && state.page) {
        _setPageState(state.page);

        // Restore specific states if present
        if (state.selectedBook) setSelectedBook(state.selectedBook);
        if (state.editingBookId) setEditingBookId(state.editingBookId);
        if (state.bookRequestId) setSelectedBookRequestId(state.bookRequestId);
      } else {
        _setPageState('home');
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

    _setPageState(page);
    window.history.pushState({ page, ...extraState }, '', window.location.pathname);
  };

  // Update search results when books change
  useEffect(() => {
    if (Array.isArray(books)) {
      setSearchResults(books);
    }
  }, [books]);
  
  const handleSearch = () => {
    // Use searchBooks from context which handles zip code filtering on backend
    if (zipCode) {
      searchBooks(searchQuery, zipCode);
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
  
  const handleBookSelect = (book) => {
    setSelectedBook(book);
    setCurrentPage('bookDetails', { selectedBook: book });
  };
  
  const handleEditBook = (bookId) => {
    setEditingBookId(bookId);
    setCurrentPage('editBook', { editingBookId: bookId });
  };
  
  const handleDonateBook = (bookData) => {
    // This will be handled by the BookContext
    setCurrentPage('home');
  };
  
  const renderPage = () => {
    switch (currentPage) {
      case 'home':
        return <Home 
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
      case 'login':
      case 'signup':
        // Login/signup is handled via modal (useEffect will open modal and redirect to home)
        return <Home 
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
      case 'donate':
        return <AddBook 
          setCurrentPage={setCurrentPage}
          setRedirectReason={setRedirectReason}
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
          onViewBook={handleBookSelect}
          fromProfile={previousPage === 'profile'}
        />;
      case 'myRequests':
        return <MyRequests 
          currentUser={currentUser} 
          setCurrentPage={setCurrentPage}
        />;
      default:
        return <Home 
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
      setCurrentPage('home');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentPage]);

  // Check if user is a first-time visitor and show welcome modal
  useEffect(() => {
    if (!localStorage.getItem('bookshare_welcome_seen')) {
      setIsWelcomeModalOpen(true);
    }
  }, []);

  // Handle closing welcome modal and mark as seen
  const handleCloseWelcomeModal = () => {
    setIsWelcomeModalOpen(false);
    localStorage.setItem('bookshare_welcome_seen', 'true');
  };

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
      <WelcomeModal 
        isOpen={isWelcomeModalOpen}
        onClose={handleCloseWelcomeModal}
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
  const currentYear = new Date().getFullYear();
  const startYear = 2025;
  const copyrightYear = currentYear === startYear 
    ? `${startYear}` 
    : `${startYear} - ${currentYear}`;

  return (
    <footer className="bg-gray-800 text-white py-8">
      <div className="container mx-auto px-4 text-center">
        <div className="flex items-center justify-center mb-4">
          <img src="/bsc-icon.png" alt="BookShare Community" className="h-8 w-8 mr-2" />
          <span className="text-xl font-semibold">BookShare Community</span>
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
          © {copyrightYear} {COMPANY}. All rights reserved.
        </div>
        <div className="text-xs text-gray-500 mt-2">
          Version {VERSION}
        </div>
      </div>
    </footer>
  );
};

export default BookDonationMarketplace; 