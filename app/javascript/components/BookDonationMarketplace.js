import React, { useState, useEffect } from 'react';
import { useBooks } from '../contexts/BookContext';
import { useAuth } from '../contexts/AuthContext';
import Navbar from './Navbar';
import Home from './Home';
import AddBook from './books/AddBook';
import EditBook from './books/EditBook';
import BookList from './books/BookList';
import BookDetail from './books/BookDetail';
import Profile from './profile/Profile';
import MyBooks from './profile/MyBooks';
import MyRequests from './profile/MyRequests';
import {
  MagnifyingGlassIcon,
  ArrowUpTrayIcon,
  UserIcon,
  ChatBubbleLeftRightIcon,
  MapPinIcon,
  ShieldCheckIcon
} from '@heroicons/react/24/outline';

// Main App Component
const BookDonationMarketplace = () => {
  const { currentUser } = useAuth();
  const { books, fetchBooks, loading } = useBooks();
  const [currentPage, _setPageState] = useState('home');
  const [searchResults, setSearchResults] = useState([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [zipCode, setZipCode] = useState('');
  const [selectedBook, setSelectedBook] = useState(null);
  const [editingBookId, setEditingBookId] = useState(null);
  const [redirectReason, setRedirectReason] = useState(null);
  const [isLoginModalOpen, setIsLoginModalOpen] = useState(false);
  const [pendingNavigation, setPendingNavigation] = useState(null);

  // Load books on mount
  useEffect(() => {
    fetchBooks();
  }, []);

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
      } else {
        _setPageState('home');
      }
    };

    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, []);

  // Navigation wrapper to sync with history
  const setCurrentPage = (page, extraState = {}) => {
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
    // Filter books based on search query (title or author)
    const query = searchQuery.toLowerCase();
    const results = Array.isArray(books) ? books.filter(book =>
      book.title.toLowerCase().includes(query) ||
      book.author.toLowerCase().includes(query)
    ) : [];

    setSearchResults(results);
  };

  const handleBookSelect = (book) => {
    setSelectedBook(book);
    if (!currentUser) {
      setPendingNavigation('bookDetails');
      setIsLoginModalOpen(true);
    } else {
      setCurrentPage('bookDetails', { selectedBook: book });
    }
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
        return <LoginPage
          setCurrentPage={setCurrentPage}
        />;
      case 'signup':
        return <SignupPage
          setCurrentPage={setCurrentPage}
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
      <Footer />
    </div>
  );
};

// Simple Footer Component
const Footer = () => {
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
        <div className="text-sm text-gray-400">
          © 2024 BookShare Community. All rights reserved.
        </div>
      </div>
    </footer>
  );
};



// Simple Messages Page Component (placeholder)
const MessagesPage = ({ setCurrentPage, currentUser }) => {
  return (
    <div className="container mx-auto py-8 px-4 max-w-4xl">
      <div className="bg-white rounded-lg shadow-md p-6">
        <h2 className="text-2xl font-bold mb-6">Messages</h2>
        <p className="text-center text-gray-600 mb-4">
          Messaging functionality will be implemented here.
        </p>
        <button
          onClick={() => setCurrentPage('home')}
          className="bg-emerald-600 text-white py-2 px-4 rounded-md hover:bg-emerald-700"
        >
          Back to Home
        </button>
      </div>
    </div>
  );
};

export default BookDonationMarketplace; 