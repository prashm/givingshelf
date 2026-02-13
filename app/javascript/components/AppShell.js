import React, { useState, useEffect } from 'react';
import { ItemProvider, useItems } from '../contexts/ItemContext';
import { useAuth } from '../contexts/AuthContext';
import Navbar from './Navbar';
import LandingPage from './LandingPage';
import ItemList from './ItemList';
import AddBook from './books/AddBook';
import AddToy from './toys/AddToy';
import EditBook from './books/EditBook';
import EditToy from './toys/EditToy';
import ItemDetailPage from './items/ItemDetailPage';
import BookRequestDetail from './messages/BookRequestDetail';
import MessagesPage from './messages/MessagesPage';
import Profile from './profile/Profile';
import MyItems from './profile/MyItems';
import MyRequests from './profile/MyRequests';
import MyGroups from './profile/MyGroups';
import GroupLanding from './group/GroupLanding';
import PrivacyPolicyModal from './PrivacyPolicyModal';
import TermsOfServiceModal from './TermsOfServiceModal';
import axios from '../lib/axios';
import { parsePageFromPath } from '../lib/textUtils';
import * as Constants from '../lib/constants';

const getUrlForPage = (page, extraState = {}) => {
  if (page === 'books') return '/books';
  if (page === 'toys') return '/toys';
  if (page === 'editBook') return '/books';
  if (page === 'editToy') return '/toys';
  if (page === 'home') return '/';
  if (page === 'myGroups') return '/my-groups';
  if (page === 'groupLanding' && extraState.groupShortName) return `/g/${extraState.groupShortName}`;
  if (page === 'groupBrowse' && extraState.groupShortName) {
    return extraState.itemType === Constants.ITEM_TYPE_TOY ? `/g/${extraState.groupShortName}/toys` : `/g/${extraState.groupShortName}/books`;
  }
  return window.location.pathname;
};

const AppShellContent = ({ onNavigate }) => {
  const { currentUser, loading: authLoading } = useAuth();
  const { items, searchItems, fetchItems } = useItems();

  const getInitialState = () => {
    if (typeof window !== 'undefined') {
      const hist = window.history.state;
      if (hist && hist.page) {
        return {
          page: hist.page,
          groupShortName: hist.groupShortName || null,
          itemType: hist.itemType || null
        };
      }
      return parsePageFromPath(window.location.pathname);
    }
    return { page: 'home', groupShortName: null, itemType: null };
  };

  const [currentPage, _setPageState] = useState(() => getInitialState().page);
  const [groupShortName, setGroupShortName] = useState(() => getInitialState().groupShortName);
  const [currentItemType, setCurrentItemType] = useState(() => getInitialState().itemType);
  const [previousPage, setPreviousPage] = useState(null);
  const [searchResults, setSearchResults] = useState([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [zipCode, setZipCode] = useState('');
  const [selectedBook, setSelectedBook] = useState(() => {
    const hist = typeof window !== 'undefined' ? window.history.state : null;
    return (hist?.page === 'bookDetails' && hist?.selectedBook) ? hist.selectedBook : null;
  });
  const [editingBookId, setEditingBookId] = useState(() => {
    const hist = typeof window !== 'undefined' ? window.history.state : null;
    return (hist?.page === 'editBook' && hist?.editingBookId) ? hist.editingBookId : null;
  });
  const [editingToyId, setEditingToyId] = useState(() => {
    const hist = typeof window !== 'undefined' ? window.history.state : null;
    return (hist?.page === 'editToy' && hist?.editingToyId) ? hist.editingToyId : null;
  });
  const [selectedBookRequestId, setSelectedBookRequestId] = useState(() => {
    const hist = typeof window !== 'undefined' ? window.history.state : null;
    return (hist?.page === 'bookRequestDetails' && hist?.bookRequestId) ? hist.bookRequestId : null;
  });
  const [redirectReason, setRedirectReason] = useState(null);
  const [donateInitialTitle, setDonateInitialTitle] = useState(null);
  const [donateItemType, setDonateItemType] = useState(() => {
    if (typeof window !== 'undefined' && window.history.state?.page === 'donate') {
      return window.history.state.donateItemType || Constants.ITEM_TYPE_BOOK;
    }
    return Constants.ITEM_TYPE_BOOK;
  });
  const [bookDetailSource, setBookDetailSource] = useState(() => {
    const hist = typeof window !== 'undefined' ? window.history.state : null;
    return (hist?.page === 'bookDetails' && hist?.bookDetailSource) ? hist.bookDetailSource : null;
  });
  const [selectedItemType, setSelectedItemType] = useState(() => {
    const hist = typeof window !== 'undefined' ? window.history.state : null;
    return (hist?.page === 'bookDetails' && hist?.selectedItemType) ? hist.selectedItemType : null;
  });
  const [isLoginModalOpen, setIsLoginModalOpen] = useState(false);
  const [pendingNavigation, setPendingNavigation] = useState(null);
  const [zipCodeDetected, setZipCodeDetected] = useState(false);
  const [isPrivacyModalOpen, setIsPrivacyModalOpen] = useState(false);
  const [isTermsModalOpen, setIsTermsModalOpen] = useState(false);

  useEffect(() => {
    const hist = typeof window !== 'undefined' ? window.history.state : null;
    const parsed = parsePageFromPath(typeof window !== 'undefined' ? window.location.pathname : '/');
    const source = hist?.page ? hist : parsed;
    if (source.groupShortName) setGroupShortName(source.groupShortName);
    if (hist?.page && currentPage !== hist.page) _setPageState(hist.page);
    else if (!hist?.page && currentPage !== parsed.page) _setPageState(parsed.page);
    if (source.itemType) setCurrentItemType(source.itemType);
  }, []);

  const isItemBrowsePage = currentPage === 'books' || currentPage === 'toys';

  // Detect zip code when on books or toys page
  useEffect(() => {
    if (!isItemBrowsePage) return;
    // Don't run until auth check is complete
    if (authLoading) return;
    // Don't run if we've already detected zip code
    if (zipCodeDetected) return;

    const detectZipCode = async () => {
      if (currentUser && currentUser.zip_code) {
        setZipCode(currentUser.zip_code);
        setZipCodeDetected(true);
        searchItems('', currentUser.zip_code);
        return;
      }
      const detectZipFromIP = async () => {
        try {
          const response = await axios.get('/api/location/detect_zip', { withCredentials: true });
          if (response.data.zip_code) {
            setZipCode(response.data.zip_code);
            setZipCodeDetected(true);
            searchItems('', response.data.zip_code);
          } else {
            setZipCodeDetected(true);
            fetchItems();
          }
        } catch (error) {
          console.error('Error detecting zip code:', error);
          setZipCodeDetected(true);
          fetchItems();
        }
      };
      if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(
          async (position) => {
            try {
              const response = await axios.get('/api/location/detect_zip', {
                params: { latitude: position.coords.latitude, longitude: position.coords.longitude },
                withCredentials: true
              });
              if (response.data.zip_code) {
                setZipCode(response.data.zip_code);
                setZipCodeDetected(true);
                searchItems('', response.data.zip_code);
              } else detectZipFromIP();
            } catch (error) {
              detectZipFromIP();
            }
          },
          () => detectZipFromIP(),
          { timeout: 5000, maximumAge: 600000 }
        );
      } else {
        detectZipFromIP();
      }
    };
    detectZipCode();
  }, [currentPage, currentUser, authLoading, zipCodeDetected, searchItems, fetchItems]);

  // Scroll to top when page changes
  useEffect(() => {
    window.scrollTo({ top: 0, left: 0, behavior: 'instant' });
  }, [currentPage]);

  useEffect(() => {
    const parsed = parsePageFromPath(window.location.pathname);
    if (parsed.groupShortName) setGroupShortName(parsed.groupShortName);
    if (parsed.itemType) setCurrentItemType(parsed.itemType);
    window.history.replaceState({ page: parsed.page, groupShortName: parsed.groupShortName, itemType: parsed.itemType }, '', window.location.pathname);

    const handlePopState = (event) => {
      const state = event.state;
      if (state?.page) {
        _setPageState(state.page);
        if (state.selectedBook) setSelectedBook(state.selectedBook);
        if (state.editingBookId) setEditingBookId(state.editingBookId);
        if (state.editingToyId) setEditingToyId(state.editingToyId);
        if (state.bookRequestId) setSelectedBookRequestId(state.bookRequestId);
        if (state.donateInitialTitle !== undefined) setDonateInitialTitle(state.donateInitialTitle);
        if (state.bookDetailSource !== undefined) setBookDetailSource(state.bookDetailSource);
        if (state.selectedItemType !== undefined) setSelectedItemType(state.selectedItemType);
        if (state.groupShortName) setGroupShortName(state.groupShortName);
        if (state.itemType) setCurrentItemType(state.itemType);
        if (state.donateItemType) setDonateItemType(state.donateItemType);
      } else {
        const parsed2 = parsePageFromPath(window.location.pathname);
        _setPageState(parsed2.page);
        setGroupShortName(parsed2.groupShortName);
        setCurrentItemType(parsed2.itemType);
      }
    };
    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, []);

  const setCurrentPage = (page, extraState = {}) => {
    setPreviousPage(currentPage);
    if (extraState.selectedBook) setSelectedBook(extraState.selectedBook);
    if (extraState.editingBookId) setEditingBookId(extraState.editingBookId);
    if (extraState.editingToyId) setEditingToyId(extraState.editingToyId);
    if (extraState.bookRequestId) setSelectedBookRequestId(extraState.bookRequestId);
    if (page === 'donate') {
      setDonateInitialTitle(extraState.donateInitialTitle ?? null);
      setDonateItemType(extraState.donateItemType ?? Constants.ITEM_TYPE_BOOK);
    }
    if (extraState.bookDetailSource !== undefined) setBookDetailSource(extraState.bookDetailSource);
    if (extraState.selectedItemType !== undefined) setSelectedItemType(extraState.selectedItemType);
    if (extraState.groupShortName) setGroupShortName(extraState.groupShortName);
    if (extraState.itemType) setCurrentItemType(extraState.itemType);
    _setPageState(page);
    const url = getUrlForPage(page, { ...extraState, groupShortName: extraState.groupShortName || groupShortName, itemType: extraState.itemType || currentItemType });
    window.history.pushState({ page, ...extraState }, '', url);
    if (typeof onNavigate === 'function') onNavigate();
  };

  useEffect(() => {
    if (Array.isArray(items)) setSearchResults(items);
  }, [items]);

  const handleSearch = (searchRadius = null) => {
    if (zipCode) {
      searchItems(searchQuery, zipCode, false, searchRadius);
    } else {
      const query = searchQuery.toLowerCase();
      const results = Array.isArray(items) ? items.filter(item =>
        item.title?.toLowerCase().includes(query) ||
        (item.author && item.author.toLowerCase().includes(query)) ||
        (item.brand && item.brand.toLowerCase().includes(query))
      ) : [];
      setSearchResults(results);
    }
  };

  const handleItemSelect = (item, source = 'browse', itemTypeHint = null) => {
    setSelectedBook(item);
    setBookDetailSource(source);
    const extraState = { selectedBook: item, bookDetailSource: source, selectedItemType: itemTypeHint };
    if (source === 'groupPage' && groupShortName) extraState.groupShortName = groupShortName;
    setCurrentPage('bookDetails', extraState);
  };

  const handleEditBook = (bookId) => {
    setEditingBookId(bookId);
    setCurrentPage('editBook', { editingBookId: bookId });
  };

  const handleEditToy = (toyId) => {
    setEditingToyId(toyId);
    setCurrentPage('editToy', { editingToyId: toyId });
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
        return donateItemType === Constants.ITEM_TYPE_TOY ? (
          <AddToy setCurrentPage={setCurrentPage} setRedirectReason={setRedirectReason} previousPage={previousPage} />
        ) : (
          <AddBook setCurrentPage={setCurrentPage} setRedirectReason={setRedirectReason} initialTitle={donateInitialTitle} previousPage={previousPage} />
        );
      case 'editBook':
        return <EditBook
          setCurrentPage={setCurrentPage}
          bookId={editingBookId}
        />;
      case 'editToy':
        return <EditToy
          setCurrentPage={setCurrentPage}
          toyId={editingToyId}
        />;
      case 'bookDetails':
        return <ItemDetailPage
          selectedItem={selectedBook}
          hintItemType={selectedItemType}
          setCurrentPage={setCurrentPage}
          currentUser={currentUser}
          onEditBook={handleEditBook}
          onEditToy={handleEditToy}
          onOpenLoginModal={handleOpenLoginModal}
          setRedirectReason={setRedirectReason}
          sourcePage={bookDetailSource}
        />;
      case 'books':
        return <ItemList itemType={Constants.ITEM_TYPE_BOOK} items={searchResults} searchQuery={searchQuery} setSearchQuery={setSearchQuery} zipCode={zipCode} setZipCode={setZipCode} handleSearch={handleSearch} handleItemSelect={handleItemSelect} currentUser={currentUser} setCurrentPage={setCurrentPage} onOpenLoginModal={handleOpenLoginModal} />;
      case 'toys':
        return <ItemList itemType={Constants.ITEM_TYPE_TOY} items={searchResults} searchQuery={searchQuery} setSearchQuery={setSearchQuery} zipCode={zipCode} setZipCode={setZipCode} handleSearch={handleSearch} handleItemSelect={handleItemSelect} currentUser={currentUser} setCurrentPage={setCurrentPage} onOpenLoginModal={handleOpenLoginModal} />;
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
      case 'myItems':
        return <MyItems
          currentUser={currentUser}
          setCurrentPage={setCurrentPage}
          onEditBook={handleEditBook}
          onEditToy={handleEditToy}
          onViewBook={(item) => handleItemSelect(item, 'myItems')}
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
      case 'groupLanding':
        return <GroupLanding groupShortName={groupShortName} currentUser={currentUser} setCurrentPage={setCurrentPage} onOpenLoginModal={handleOpenLoginModal} />;
      case 'groupBrowse':
        return <ItemList itemType={currentItemType || Constants.ITEM_TYPE_BOOK} groupShortName={groupShortName} items={searchResults} searchQuery={searchQuery} setSearchQuery={setSearchQuery} zipCode={zipCode} setZipCode={setZipCode} handleSearch={handleSearch} handleItemSelect={handleItemSelect} currentUser={currentUser} setCurrentPage={setCurrentPage} onOpenLoginModal={handleOpenLoginModal} />;
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
    if (profileIncomplete) {
      setCurrentPage('profile');
    } else if (pendingNavigation) {
      const nav = typeof pendingNavigation === 'object' ? pendingNavigation : { page: pendingNavigation };
      const extraState = nav.page === 'bookDetails' ? { selectedBook } : nav.donateItemType ? { donateItemType: nav.donateItemType } : {};
      setCurrentPage(nav.page, { ...extraState, ...nav });
      setPendingNavigation(null);
    }
  };

  const handleOpenLoginModal = (destinationPage = null, options = {}) => {
    if (destinationPage) {
      setPendingNavigation(typeof destinationPage === 'object' ? destinationPage : { page: destinationPage, ...options });
    }
    setIsLoginModalOpen(true);
  };

  const handleCloseLoginModal = () => {
    setIsLoginModalOpen(false);
    setPendingNavigation(null);
  };

  useEffect(() => {
    if (currentPage === 'login' || currentPage === 'signup') {
      handleOpenLoginModal();
      setCurrentPage('books');
    }
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
          currentPage={currentPage}
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

const AppShell = () => {
  const [pathKey, setPathKey] = useState(0);
  const parsed = parsePageFromPath(typeof window !== 'undefined' ? window.location.pathname : '/');
  const hist = typeof window !== 'undefined' ? window.history.state : null;
  const donateItemTypeFromState = hist?.donateItemType || Constants.ITEM_TYPE_BOOK;
  const effectivePage = hist?.page || parsed.page;
  const providerItemType = effectivePage === 'books' ? Constants.ITEM_TYPE_BOOK
    : effectivePage === 'toys' ? Constants.ITEM_TYPE_TOY
    : effectivePage === 'editToy' ? Constants.ITEM_TYPE_TOY
    : effectivePage === 'groupBrowse' ? (hist?.itemType || parsed.itemType || Constants.ITEM_TYPE_BOOK)
    : effectivePage === 'bookDetails' ? (hist?.selectedItemType || parsed.itemType || Constants.ITEM_TYPE_BOOK)
    : effectivePage === 'donate' ? donateItemTypeFromState
    : Constants.ITEM_TYPE_BOOK;

  useEffect(() => {
    const handlePopState = () => setPathKey(k => k + 1);
    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, []);

  const onNavigate = () => setPathKey(k => k + 1);

  return (
    <ItemProvider key={`${providerItemType}-${pathKey}`} itemType={providerItemType}>
      <AppShellContent onNavigate={onNavigate} />
    </ItemProvider>
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
          <img src="/gs-logo.png" alt="GivingShelf" className="h-24 w-96 mr-2" />
        </div>
        <p className="text-gray-300 mb-4">
          Connecting communities through local giving.
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

export default AppShell;
