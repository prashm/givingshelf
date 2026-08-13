import React, { useState } from 'react';
import { XMarkIcon } from '@heroicons/react/24/outline';
import axios from '../../lib/axios';
import {
  DEFAULT_WISHLIST_MESSAGE,
  normalizedBookFieldsFromGoogleAutocomplete
} from '../../lib/googleBookFieldsFromVolume';
import { getHostGroupShortName } from '../../lib/groupSubdomain';
import * as Constants from '../../lib/constants';

const cardShell = 'bg-white rounded-lg shadow-md overflow-hidden h-full flex flex-col';
const MESSAGE_MIN = 10;
const MESSAGE_MAX = 500;

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
  const [showConfirmModal, setShowConfirmModal] = useState(false);
  const [requestMessage, setRequestMessage] = useState(DEFAULT_WISHLIST_MESSAGE);
  const [modalError, setModalError] = useState('');

  if (!selectedSuggestion) {
    return null;
  }

  const openConfirmModal = () => {
    setError(null);
    if (!currentUser) {
      onOpenLoginModal?.({
        page: (window.location.pathname.includes('/g/') || Boolean(getHostGroupShortName())) ? 'groupBrowse' : 'books'
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
    setRequestMessage(DEFAULT_WISHLIST_MESSAGE);
    setModalError('');
    setShowConfirmModal(true);
  };

  const closeConfirmModal = () => {
    if (submitting) return;
    setShowConfirmModal(false);
    setModalError('');
  };

  const submitWishlistRequest = async (e) => {
    e.preventDefault();
    const message = requestMessage.trim();
    if (message.length < MESSAGE_MIN) {
      setModalError(`Message must be at least ${MESSAGE_MIN} characters.`);
      return;
    }
    if (message.length > MESSAGE_MAX) {
      setModalError(`Message is too long (maximum ${MESSAGE_MAX} characters).`);
      return;
    }
    if (!wishlistScope?.community_group_id) {
      setModalError('You can request this book when your profile ZIP or group membership matches this search.');
      return;
    }

    const normalizedFields = normalizedBookFieldsFromGoogleAutocomplete(selectedSuggestion);
    const body = {
      type: Constants.ITEM_TYPE_BOOK,
      item: {
        ...normalizedFields,
        community_group_id: wishlistScope.community_group_id,
        ...(wishlistScope.sub_group_id ? { sub_group_id: wishlistScope.sub_group_id } : {}),
        message
      }
    };

    setModalError('');
    setSubmitting(true);
    try {
      const res = await axios.post('/api/items/wishlist', body, { withCredentials: true });
      const id = res.data?.item_request_id;
      if (id) {
        setShowConfirmModal(false);
        setCurrentPage('itemRequestDetails', { itemRequestId: String(id) });
      } else {
        setModalError('Unexpected response. Please try again.');
      }
    } catch (err) {
      const msg = err.response?.data?.errors?.[0] || err.response?.data?.errors
        || err.response?.data?.error || 'Could not create wishlist request.';
      setModalError(typeof msg === 'string' ? msg : (Array.isArray(msg) ? msg.join(', ') : 'Request failed.'));
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
    <>
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
            onClick={openConfirmModal}
            disabled={submitting}
            className="mt-3 w-full py-2.5 rounded-md text-sm font-medium text-white bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            Place request
          </button>
          {error && (
            <p className="mt-2 text-sm text-red-600 text-center">{error}</p>
          )}
        </div>
      </div>

      {showConfirmModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-40 flex items-center justify-center px-4">
          <div className="bg-white rounded-lg shadow-xl max-w-lg w-full p-6 relative">
            <button
              type="button"
              onClick={closeConfirmModal}
              className="absolute top-3 right-3 text-gray-400 hover:text-gray-600"
              disabled={submitting}
            >
              <XMarkIcon className="h-6 w-6" />
            </button>
            <h2 className="text-xl font-semibold text-gray-900 mb-2">Confirm Wishlist Request</h2>
            <p className="text-sm text-gray-600 mb-4">
              Add a short message before placing the request.
            </p>
            <form onSubmit={submitWishlistRequest} className="space-y-4">
              <div>
                <label htmlFor="wishlist-request-message" className="block text-sm font-medium text-gray-700 mb-1">
                  Your message
                </label>
                <textarea
                  id="wishlist-request-message"
                  className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                  rows={4}
                  value={requestMessage}
                  onChange={(e) => setRequestMessage(e.target.value)}
                  disabled={submitting}
                  maxLength={MESSAGE_MAX}
                />
                {modalError && <p className="mt-1 text-sm text-red-600">{modalError}</p>}
              </div>
              <div className="flex justify-end gap-3">
                <button
                  type="button"
                  onClick={closeConfirmModal}
                  className="px-4 py-2 text-sm rounded-md border border-gray-300 text-gray-700 hover:bg-gray-50"
                  disabled={submitting}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 text-sm rounded-md bg-emerald-600 text-white hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed"
                  disabled={submitting}
                >
                  {submitting ? 'Placing request…' : 'Place request'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
};

export default WishlistBookCard;
