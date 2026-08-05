import React, { useState } from 'react';
import axios from '../../lib/axios';
import { normalizedBookFieldsFromGoogleAutocomplete } from '../../lib/googleBookFieldsFromVolume';
import { getHostGroupShortName } from '../../lib/groupSubdomain';
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

/**
 * Wishlist CTA for a book the user explicitly picked from Google Books autocomplete.
 * Does not guess a match from free-text search.
 */
const WishlistBookCard = ({
  selectedSuggestion = null,
  wishlistScope = null,
  currentUser,
  setCurrentPage,
  onOpenLoginModal,
  setRedirectReason
}) => {
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  if (!selectedSuggestion) {
    return null;
  }

  const placeRequest = async () => {
    setError(null);
    if (!currentUser) {
      const normalizedFields = normalizedBookFieldsFromGoogleAutocomplete(selectedSuggestion);
      const body = wishlistScope?.community_group_id ? {
        type: Constants.ITEM_TYPE_BOOK,
        item: {
          ...normalizedFields,
          community_group_id: wishlistScope.community_group_id,
          ...(wishlistScope.sub_group_id ? { sub_group_id: wishlistScope.sub_group_id } : {})
        }
      } : null;
      onOpenLoginModal?.({
        page: (window.location.pathname.includes("/g/") || Boolean(getHostGroupShortName())) ? "groupBrowse" : "books",
        ...(body ? { afterLoginAction: { type: 'createWishlist', body } } : {})
      });
      return;
    }
    if (!currentUser.profile_complete) {
      const profilePrompt = 'Please complete your profile first before placing your request.';
      setRedirectReason?.(profilePrompt);
      setCurrentPage('profile', { redirectReason: profilePrompt });
      return;
    }
    if (!wishlistScope?.community_group_id) {
      setError('You can request this book when your profile ZIP or group membership matches this search.');
      return;
    }
    const normalizedFields = normalizedBookFieldsFromGoogleAutocomplete(selectedSuggestion);
    const body = {
      type: Constants.ITEM_TYPE_BOOK,
      item: {
        ...normalizedFields,
        community_group_id: wishlistScope.community_group_id,
        ...(wishlistScope.sub_group_id ? { sub_group_id: wishlistScope.sub_group_id } : {})
      }
    };
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

  const thumb = selectedSuggestion.thumbnail
    ? selectedSuggestion.thumbnail.replace(/^http:/, 'https:')
    : null;
  const primaryCategory = Array.isArray(selectedSuggestion.categories) && selectedSuggestion.categories[0]
    ? selectedSuggestion.categories[0]
    : '—';

  return (
    <div className={cardShell}>
      <div className="flex justify-center items-center bg-gray-50" style={{ height: '200px' }}>
        {thumb ? (
          <img
            src={thumb}
            alt={selectedSuggestion.title}
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
          {selectedSuggestion.title}
        </h3>
        {selectedSuggestion.authors?.length > 0 && (
          <p className="text-gray-600 mb-2">by {selectedSuggestion.authors.join(', ')}</p>
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
          Place a request — we&apos;ll email members who might have this book.
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
