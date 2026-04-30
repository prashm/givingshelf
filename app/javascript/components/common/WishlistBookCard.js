import React, { useState, useEffect, useRef } from 'react';
import axios from '../../lib/axios';
import { searchGoogleBooks } from '../../lib/googleBooksApi';
import { normalizedBookFieldsFromGoogleAutocomplete } from '../../lib/googleBookFieldsFromVolume';
import * as Constants from '../../lib/constants';

const cardShell = 'bg-white rounded-lg shadow-md overflow-hidden h-full flex flex-col';

const BookPlaceholderIcon = () => (
  <div className="flex flex-col items-center justify-center text-gray-400">
    <svg className="w-16 h-16 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
    </svg>
    <span className="text-sm">No Cover</span>
  </div>
);

const calloutClass =
  'mt-3 rounded-md border border-amber-200 bg-amber-50 px-3 py-2.5 text-sm text-amber-950 text-center sm:text-left';

const WishlistBookCard = ({
  searchQuery,
  selectedSuggestion = null,
  wishlistScope = null,
  currentUser,
  setCurrentPage,
  onOpenLoginModal,
  setRedirectReason
}) => {
  const [suggestion, setSuggestion] = useState(null);
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);
  const abortRef = useRef(null);

  useEffect(() => {
    if (selectedSuggestion) {
      if (abortRef.current) {
        abortRef.current.abort();
        abortRef.current = null;
      }
      setSuggestion(selectedSuggestion);
      setLoading(false);
      setError(null);
      return;
    }

    const q = (searchQuery || '').trim();
    if (q.length < 2) {
      if (abortRef.current) {
        abortRef.current.abort();
        abortRef.current = null;
      }
      setLoading(false);
      return;
    }

    if (abortRef.current) {
      abortRef.current.abort();
    }
    const ac = new AbortController();
    abortRef.current = ac;
    setLoading(true);
    setError(null);
    (async () => {
      try {
        const list = await searchGoogleBooks(q, { signal: ac.signal });
        if (ac.signal.aborted) return;
        setSuggestion(list[0] || null);
        setError(null);
      } catch (e) {
        if (e.name === 'AbortError') return;
        setSuggestion(null);
        setError('Could not load a book match from Google. Try a different search.');
      } finally {
        if (!ac.signal.aborted) setLoading(false);
      }
    })();
    return () => { ac.abort(); };
  }, [searchQuery, selectedSuggestion]);

  const placeRequest = async () => {
    if (!suggestion) return;
    if (!wishlistScope?.community_group_id) return;
    setError(null);
    const normalizedFields = normalizedBookFieldsFromGoogleAutocomplete(suggestion);
    const body = {
      type: Constants.ITEM_TYPE_BOOK,
      item: {
        ...normalizedFields,
        community_group_id: wishlistScope.community_group_id,
        ...(wishlistScope.sub_group_id ? { sub_group_id: wishlistScope.sub_group_id } : {})
      }
    };
    if (!currentUser) {
      onOpenLoginModal?.({
        page: window.location.pathname.includes("/g/") ? "groupBrowse" : "books",
        afterLoginAction: { type: 'createWishlist', body }
      });
      return;
    }
    if (!currentUser.profile_complete) {
      setRedirectReason?.('Please complete your profile to request books.');
      setCurrentPage('profile');
      return;
    }
    setSubmitting(true);
    try {
      const res = await axios.post('/api/items/wishlist', body, { withCredentials: true });
      const id = res.data?.item_request_id;
      if (id) {
        setCurrentPage('itemRequestDetails', { itemRequestId: String(id) });
      } else {
        setError('Unexpected response. Please try again.');
      }
    } catch (err) {
      const msg = err.response?.data?.errors?.[0] || err.response?.data?.errors
        || err.response?.data?.error || 'Could not create wishlist request.';
      setError(typeof msg === 'string' ? msg : (Array.isArray(msg) ? msg.join(', ') : 'Request failed.'));
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <div className={cardShell}>
        <div className="flex justify-center items-center bg-gray-50" style={{ height: '200px' }}>
          <div className="h-7 w-7 animate-spin rounded-full border-2 border-gray-200 border-b-emerald-600" />
        </div>
        <div className="p-4 flex-1">
          <p className="text-gray-600 text-sm text-center">Looking for a book match in Google Books…</p>
        </div>
      </div>
    );
  }

  if (error && !suggestion) {
    return (
      <div className={cardShell}>
        <div className="flex justify-center items-center bg-gray-50" style={{ height: '200px' }}>
          <BookPlaceholderIcon />
        </div>
        <div className="p-4 flex-1">
          <p className="text-red-600 text-sm text-center">{error}</p>
        </div>
      </div>
    );
  }

  if (!suggestion) {
    return (
      <div className={cardShell}>
        <div className="flex justify-center items-center bg-gray-50" style={{ height: '200px' }}>
          <BookPlaceholderIcon />
        </div>
        <div className="p-4 flex-1">
          <p className="text-gray-600 text-sm text-center">
            No close Google Books match for this search. Try another title or author.
          </p>
        </div>
      </div>
    );
  }

  const thumb = suggestion.thumbnail ? suggestion.thumbnail.replace(/^http:/, 'https:') : null;
  const primaryCategory = Array.isArray(suggestion.categories) && suggestion.categories[0]
    ? suggestion.categories[0]
    : '—';

  return (
    <div className={cardShell}>
      <div className="flex justify-center items-center bg-gray-50" style={{ height: '200px' }}>
        {thumb ? (
          <img
            src={thumb}
            alt={suggestion.title}
            className="img-box"
            onError={(e) => {
              e.target.style.display = 'none';
            }}
          />
        ) : (
          <BookPlaceholderIcon />
        )}
      </div>
      <div className="p-4 flex-1 flex flex-col">
        <h3 className="font-semibold text-lg mb-2 line-clamp-2">
          {suggestion.title}
        </h3>
        {suggestion.authors?.length > 0 && (
          <p className="text-gray-600 mb-2">by {suggestion.authors.join(', ')}</p>
        )}
        <div className="flex items-center justify-between gap-2 min-h-[1.25rem]">
          <span className="text-sm text-gray-500 truncate" title={primaryCategory}>
            {primaryCategory}
          </span>
          <span className="shrink-0 px-2 py-1 rounded-full text-xs font-medium bg-amber-100 text-amber-900">
            Wishlist
          </span>
        </div>
        <p className={calloutClass}>
          Place a community request — we&apos;ll email nearby members who might have this book.
        </p>
        <button
          type="button"
          onClick={placeRequest}
          disabled={submitting}
          className="mt-3 w-full py-2.5 rounded-md text-sm font-medium text-white bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {submitting ? 'Placing request…' : 'Place request'}
        </button>
        {error && (
          <p className="mt-2 text-sm text-red-600 text-center">{error}</p>
        )}
      </div>
    </div>
  );
};

export default WishlistBookCard;
