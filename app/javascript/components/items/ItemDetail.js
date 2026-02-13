import React, { useState, useEffect } from 'react';
import { MapPinIcon, CalendarIcon, UserIcon, ChevronLeftIcon, ChevronRightIcon, XMarkIcon, EyeIcon } from '@heroicons/react/24/outline';
import axios from '../../lib/axios';
import { useItems } from '../../contexts/ItemContext';
import VerificationBadge from '../common/VerificationBadge';
import { getGroupPageInfo } from '../../lib/textUtils';

const ItemDetail = ({
  item: initialItem,
  setCurrentPage,
  currentUser,
  onEditItem,
  onOpenLoginModal,
  setRedirectReason,
  sourcePage,
  config
}) => {
  const { getItem, requestItem } = useItems();
  const [item, setItem] = useState(initialItem);
  const [showContact, setShowContact] = useState(false);
  const [requestStatus, setRequestStatus] = useState('idle');
  const [currentImageIndex, setCurrentImageIndex] = useState(0);
  const [showImageModal, setShowImageModal] = useState(false);
  const [viewCount, setViewCount] = useState(item?.view_count || 0);
  const [viewTracked, setViewTracked] = useState(false);
  const [showRequestModal, setShowRequestModal] = useState(false);
  const [requestMessage, setRequestMessage] = useState('');
  const [requestError, setRequestError] = useState('');
  const [userRequest, setUserRequest] = useState(null);
  const [mapboxToken, setMapboxToken] = useState(null);
  const [mapImageUrl, setMapImageUrl] = useState(null);
  const [pickupMapImageUrl, setPickupMapImageUrl] = useState(null);

  const {
    itemTypeLabel = 'Item',
    getSubtitle = () => null,
    getDetailFields = () => [],
    donateSimilarLabel = 'Donate a Similar Item',
    donateLabel = 'Donate an Item',
    browseMoreLabel = 'Browse More',
    requestLabel = 'Request This Item',
    editLabel = 'Edit This Item',
    notFoundLabel = 'Item Not Found',
    emptyPlaceholder = '📦',
    emptyPlaceholderIcon = null,
    emptyStateText = 'No Cover Available',
    requestModalTitle = 'Request this item',
    requestModalDescription = "Add a short message to the donor explaining why you'd like this item or how you plan to pick it up.",
    DetailIcon = null
  } = config || {};

  const isOwner = item?.owner?.id === currentUser?.id || item?.owner_id === currentUser?.id;

  const handleBackNavigation = () => {
    if (sourcePage === 'myItems') {
      setCurrentPage('myItems');
    } else if (sourcePage === 'messages') {
      setCurrentPage('messages');
    } else if (sourcePage === 'books') {
      setCurrentPage('books');
    } else if (sourcePage === 'toys') {
      setCurrentPage('toys');
    } else {
      const { isGroupPage, groupShortName } = getGroupPageInfo();
      if ((sourcePage === 'groupPage' || isGroupPage) && groupShortName) {
        setCurrentPage('groupPage', { groupShortName });
      } else {
        setCurrentPage('books');
      }
    }
  };

  if (!item) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-4xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="text-center">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">{notFoundLabel}</h2>
            <p className="text-gray-600 mb-4">The {itemTypeLabel.toLowerCase()} you&apos;re looking for doesn&apos;t exist.</p>
            <button
              onClick={handleBackNavigation}
              className="px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700"
            >
              Back to Home
            </button>
          </div>
        </div>
      </div>
    );
  }

  useEffect(() => {
    setItem(initialItem);
    if (initialItem && !initialItem.owner && initialItem.id) {
      getItem(initialItem.id)
        .then((data) => {
          const fullItem = data;
          if (fullItem) setItem(fullItem);
        })
        .catch(error => console.error('Error fetching full item details:', error));
    }
  }, [initialItem?.id, getItem]);

  useEffect(() => {
    if (item) {
      setViewCount(item.view_count || 0);
      setViewTracked(false);
    }
  }, [item?.id]);

  useEffect(() => {
    if (!item) return;
    const isOwner = item.owner?.id === currentUser?.id;
    if (isOwner) {
      getItem(item.id)
        .then((data) => {
          const fullItem = data;
          if (fullItem) {
            setItem(fullItem);
            if (fullItem.view_count !== undefined) setViewCount(fullItem.view_count);
          }
        })
        .catch(error => console.error('Error fetching view count:', error));
    } else if (!viewTracked) {
      axios.post(`/api/items/${item.id}/track_view`, {}, { withCredentials: true })
        .then(response => {
          setViewCount(response.data.view_count);
          setViewTracked(true);
        })
        .catch(() => setViewTracked(true));
    }
  }, [item?.id, currentUser?.id, viewTracked, getItem]);

  useEffect(() => {
    if (!item || !currentUser) return;
    axios.get(`/api/items/${item.id}/user_request`, { withCredentials: true })
      .then(response => {
        setUserRequest(response.data.has_requested ? response.data.request : null);
      })
      .catch(error => console.error('Error fetching user request:', error));
  }, [item?.id, currentUser?.id]);

  useEffect(() => {
    const fetchToken = async () => {
      try {
        const response = await axios.get('/api/location/mapbox_token', { withCredentials: true });
        const token = response.data.token;
        const payload = JSON.parse(atob(token.split('.')[1]));
        setMapboxToken(payload.exp && payload.exp < Date.now() / 1000 ? null : payload.mapbox_token);
      } catch (error) {
        setMapboxToken(null);
      }
    };
    fetchToken();
  }, []);

  useEffect(() => {
    if (!mapboxToken || !item?.owner?.location) {
      setMapImageUrl(null);
      return;
    }
    const zipCode = item.owner.location;
    const geocode = async () => {
      try {
        const res = await fetch(`https://api.mapbox.com/geocoding/v5/mapbox.places/${encodeURIComponent(zipCode)}.json?country=us&types=postcode&access_token=${mapboxToken}`);
        const data = await res.json();
        if (data.features?.length > 0) {
          const [lng, lat] = data.features[0].center;
          setMapImageUrl(`https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/${lng},${lat},11/300x200@2x?access_token=${mapboxToken}`);
        } else setMapImageUrl(null);
      } catch (error) {
        setMapImageUrl(null);
      }
    };
    geocode();
  }, [mapboxToken, item?.owner?.location]);

  useEffect(() => {
    if (!mapboxToken || !item?.pickup_address) {
      setPickupMapImageUrl(null);
      return;
    }
    const address = item.pickup_address;
    const geocode = async () => {
      try {
        const res = await fetch(`https://api.mapbox.com/geocoding/v5/mapbox.places/${encodeURIComponent(address)}.json?country=us&access_token=${mapboxToken}`);
        const data = await res.json();
        if (data.features?.length > 0) {
          const [lng, lat] = data.features[0].center;
          setPickupMapImageUrl(`https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/${lng},${lat},14/300x200@2x?access_token=${mapboxToken}`);
        } else setPickupMapImageUrl(null);
      } catch (error) {
        setPickupMapImageUrl(null);
      }
    };
    geocode();
  }, [mapboxToken, item?.pickup_address]);

  const requireLogin = (callback, destinationPage = null) => {
    if (!currentUser) {
      onOpenLoginModal ? onOpenLoginModal(destinationPage) : setCurrentPage('login');
      return;
    }
    callback();
  };

  const openRequestModal = () => {
    requireLogin(() => {
      if (currentUser && !currentUser.profile_complete) {
        if (setRedirectReason) setRedirectReason(`Please complete your profile to request ${itemTypeLabel.toLowerCase()}s.`);
        setCurrentPage('profile');
        return;
      }
      setRequestMessage('');
      setRequestError('');
      setShowRequestModal(true);
    });
  };

  const handleSubmitRequest = async (e) => {
    e.preventDefault();
    const message = requestMessage.trim();
    if (!message) return;
    setRequestError('');
    setRequestStatus('requesting');
    try {
      const result = await requestItem(item.id, message);
      if (result.success) {
        setUserRequest(result.request);
        setRequestStatus('success');
        setShowRequestModal(false);
      } else {
        setRequestStatus('error');
        if (result.error?.includes('profile')) {
          setRedirectReason?.(result.error);
          setCurrentPage('profile');
        } else {
          setRequestError(result.error || 'Failed to send request. Please try again.');
        }
      }
    } catch (error) {
      setRequestStatus('error');
      setRequestError('Failed to send request. Please try again.');
    }
  };

  const handleDonateSimilarClick = () => requireLogin(() => setCurrentPage('donate', { donateInitialTitle: item.title }), 'donate');
  const handleDonateClick = () => requireLogin(() => setCurrentPage('donate'), 'donate');

  const getConditionColor = (c) => {
    const map = { excellent: 'bg-green-100 text-green-800', good: 'bg-blue-100 text-blue-800', fair: 'bg-yellow-100 text-yellow-800', poor: 'bg-red-100 text-red-800' };
    return map[c] || 'bg-gray-100 text-gray-800';
  };
  const getConditionDescription = (c) => {
    const map = { excellent: 'Like new, minimal wear', good: 'Light wear, still in good shape', fair: 'Moderate wear, readable condition', poor: 'Heavy wear, may have damage' };
    return map[c] || 'Unknown condition';
  };
  const formatPickupMethod = (m) => m ? m.split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ') : '';
  const handleBrowseMore = () => {
    const { isGroupPage, groupShortName } = getGroupPageInfo();
    setCurrentPage(isGroupPage && groupShortName ? 'groupPage' : 'books', isGroupPage && groupShortName ? { groupShortName } : {});
  };

  const subtitle = getSubtitle(item);
  const detailFields = getDetailFields(item);

  return (
    <div className="container mx-auto py-8 px-4 max-w-4xl">
      <div className="bg-white rounded-lg shadow-md overflow-hidden">
        <div className="p-6 border-b border-gray-200">
          <button onClick={handleBackNavigation} className="flex items-center gap-2 text-blue-600 hover:text-blue-700 mb-4">
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" /></svg>
            {sourcePage === 'myItems' ? 'Back to My Items' : sourcePage === 'messages' ? 'Back to Messages' : sourcePage === 'books' ? 'Back to Books' : sourcePage === 'toys' ? 'Back to Toys' : sourcePage === 'groupPage' ? 'Back to Group' : 'Back to search results'}
          </button>
          <h1 className="text-3xl font-bold text-gray-900">{item.title}</h1>
          {subtitle && <p className="text-xl text-gray-600">{subtitle}</p>}
        </div>

        <div className="md:flex">
          <div className="md:w-1/3 p-6">
            <div className="mb-6">
              {item.cover_image_url ? (
                <div className="flex justify-center">
                  <img src={item.cover_image_url} alt={item.title} className="w-16 h-20 sm:w-18 sm:h-24 md:w-20 md:h-28 object-cover rounded border shadow-sm" />
                </div>
              ) : (
                <div className="w-full h-80 bg-gray-100 rounded-lg flex items-center justify-center">
                  <div className="text-center text-gray-400">
                    {emptyPlaceholderIcon ? (
                      React.createElement(emptyPlaceholderIcon, { className: 'w-24 h-24 mx-auto mb-2', strokeWidth: 1.5 })
                    ) : (
                      <div className="text-6xl mb-2">{emptyPlaceholder}</div>
                    )}
                    <div className="text-lg">{emptyStateText}</div>
                  </div>
                </div>
              )}
            </div>

            <div className="space-y-3">
              {!isOwner ? (
                <>
                  {userRequest ? (
                    <button
                      type="button"
                      onClick={() => setCurrentPage('bookRequestDetails', { bookRequestId: userRequest.id })}
                      className="w-full bg-gray-100 text-gray-800 py-3 px-4 rounded-lg border border-gray-300 hover:bg-gray-200 transition-colors"
                    >
                      Requested on {new Date(userRequest.created_at).toLocaleString(undefined, { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}
                    </button>
                  ) : (
                    <button
                      onClick={openRequestModal}
                      disabled={requestStatus === 'requesting' || (item.can_request === false && currentUser)}
                      className="w-full bg-emerald-600 text-white py-3 px-4 rounded-lg hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                      title={item.can_request === false && currentUser && item.can_request_reason ? item.can_request_reason : ''}
                    >
                      {requestStatus === 'requesting' ? 'Sending Request...' : requestLabel}
                    </button>
                  )}
                  {requestStatus === 'error' && (
                    <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm text-center">Failed to send request. Please try again.</div>
                  )}
                </>
              ) : (
                <div className="space-y-2">
                  <div className="w-full bg-gray-50 border border-gray-200 rounded-lg py-3 px-4 flex items-center justify-center gap-2">
                    <EyeIcon className="h-5 w-5 text-gray-600" />
                    <span className="text-gray-700 font-medium">{viewCount} {viewCount === 1 ? 'view' : 'views'}</span>
                  </div>
                  <button
                    type="button"
                    onClick={() => setCurrentPage('messages')}
                    className="w-full bg-white border border-gray-300 rounded-lg py-2 px-4 text-sm text-gray-700 hover:bg-gray-50 transition-colors"
                  >
                    Total Requests: {item.request_count ?? 0}
                  </button>
                  {item.community_group_names?.length > 0 && (
                    <div className="w-full bg-gray-50 py-3 px-4">
                      <div className="text-gray-700 text-left">
                        <div className="font-medium mb-1">Shared In:</div>
                        {item.community_group_names.map((name, i) => <div key={i} className="text-sm">{name}</div>)}
                      </div>
                    </div>
                  )}
                </div>
              )}

              {onEditItem && isOwner && (
                <button onClick={() => onEditItem(item.id)} className="w-full bg-emerald-600 text-white py-3 px-4 rounded-lg hover:bg-emerald-700 transition-colors mb-3">
                  {editLabel}
                </button>
              )}

              {!isOwner && (
                <button onClick={handleDonateSimilarClick} className="w-full bg-green-600 text-white py-3 px-4 rounded-lg hover:bg-green-700 transition-colors">
                  {donateSimilarLabel}
                </button>
              )}
            </div>

            {detailFields.length > 0 && (
              <div className="mt-6 p-4 bg-gray-50 rounded-lg">
                <h3 className="font-semibold text-gray-900 mb-3">{itemTypeLabel} Details</h3>
                <div className="space-y-2 text-sm">
                  {detailFields.map((f, i) => {
                    const Icon = f.icon;
                    return (
                      <div key={i} className="flex items-center gap-2">
                        {Icon && <Icon className="h-4 w-4 text-gray-400" />}
                        <span className="text-gray-600">{f.label}:</span>
                        <span className="font-medium">{f.value ?? '-'}</span>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
          </div>

          <div className="md:w-2/3 p-6">
            <div className="mb-6">
              <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${getConditionColor(item.condition)}`}>
                {item.condition?.charAt(0).toUpperCase() + item.condition?.slice(1)} Condition
              </span>
              <p className="text-sm text-gray-600 mt-1">{getConditionDescription(item.condition)}</p>
            </div>

            {item.summary && (
              <div className="mb-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-2">Summary</h3>
                <p className="text-gray-700 leading-relaxed">{item.summary}</p>
              </div>
            )}

            <div className="mb-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-3">About This {itemTypeLabel}</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-4">
                  <div className="flex items-center gap-3">
                    <UserIcon className="h-4 w-4 text-gray-400" />
                    <div>
                      <span className="text-sm font-medium text-gray-500">Donor</span>
                      {currentUser ? (
                        <div className="text-gray-900 flex items-center gap-2">
                          {item.owner?.name || 'Anonymous'}
                          {item.owner && <VerificationBadge trustScore={item.owner.trust_score} size="md" verified={item.owner.verified} />}
                        </div>
                      ) : <p className="text-gray-900">Hidden</p>}
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <CalendarIcon className="h-4 w-4 text-gray-400" />
                    <div>
                      <span className="text-sm font-medium text-gray-500">Added</span>
                      <p className="text-gray-900">{new Date(item.created_at).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    {DetailIcon && <DetailIcon className="h-4 w-4 text-gray-400" />}
                    <div>
                      <span className="text-sm font-medium text-gray-500">Status</span>
                      <p className="text-gray-900">{item.status_display || 'Available'}</p>
                    </div>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <MapPinIcon className="h-4 w-4 text-gray-400 mt-1" />
                  <div className="flex-1">
                    <span className="text-sm font-medium text-gray-500">Location</span>
                    {item.pickup_method && <p className="text-gray-700 text-sm mt-0.5 mb-2">{formatPickupMethod(item.pickup_method)}</p>}
                    {item.pickup_address && currentUser ? (
                      <div>
                        <p className="text-gray-900 mb-2">{item.pickup_address}</p>
                        {pickupMapImageUrl && <img src={pickupMapImageUrl} alt={`Map of ${item.pickup_address}`} className="mt-2 w-full h-40 object-cover rounded-lg border border-gray-200" onError={e => { e.target.style.display = 'none'; }} />}
                      </div>
                    ) : item.owner?.location ? (
                      <div>
                        <p className="text-gray-900 mb-2">{item.owner.location}</p>
                        {mapImageUrl && <img src={mapImageUrl} alt={`Map of ${item.owner.location}`} className="mt-2 w-full h-40 object-cover rounded-lg border border-gray-200" onError={e => { e.target.style.display = 'none'; }} />}
                      </div>
                    ) : (
                      <p className="text-gray-900">Not specified</p>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {item.user_images_urls?.length > 0 && (
              <div className="mb-6">
                <div className="flex overflow-x-auto gap-2 pb-2">
                  {item.user_images_urls.map((url, i) => (
                    <img key={i} src={url} alt={`${itemTypeLabel} photo ${i + 1}`} onClick={() => { setCurrentImageIndex(i); setShowImageModal(true); }} className="h-32 w-32 object-cover rounded-lg cursor-pointer hover:opacity-80 flex-shrink-0 border-2 border-gray-200" />
                  ))}
                </div>
              </div>
            )}

            {item.personal_note && <div className="mb-6"><p className="text-gray-700 leading-relaxed whitespace-pre-line">{item.personal_note}</p></div>}

            <div className="mt-8 p-4 bg-gray-50 rounded-lg">
              <h3 className="font-semibold text-gray-900 mb-3">Looking for more?</h3>
              <p className="text-gray-600 mb-3">Discover similar {itemTypeLabel.toLowerCase()}s or explore others in your area.</p>
              <div className="flex gap-3">
                <button onClick={handleBrowseMore} className="px-4 py-2 bg-gray-600 text-white rounded-md hover:bg-gray-700 transition-colors">{browseMoreLabel}</button>
                <button onClick={handleDonateClick} className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition-colors">{donateLabel}</button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {showRequestModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-40 flex items-center justify-center px-4">
          <div className="bg-white rounded-lg shadow-xl max-w-lg w-full p-6 relative">
            <button type="button" onClick={() => setShowRequestModal(false)} className="absolute top-3 right-3 text-gray-400 hover:text-gray-600"><XMarkIcon className="h-6 w-6" /></button>
            <h2 className="text-xl font-semibold text-gray-900 mb-2">{requestModalTitle}</h2>
            <p className="text-sm text-gray-600 mb-4">{requestModalDescription}</p>
            <form onSubmit={handleSubmitRequest} className="space-y-4">
              <div>
                <label htmlFor="request-message" className="block text-sm font-medium text-gray-700 mb-1">Message to donor</label>
                <textarea id="request-message" className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" rows={4} value={requestMessage} onChange={e => setRequestMessage(e.target.value)} disabled={requestStatus === 'requesting'} />
                {requestError && <p className="mt-1 text-sm text-red-600">{requestError}</p>}
              </div>
              <div className="flex justify-end gap-3">
                <button type="button" onClick={() => setShowRequestModal(false)} className="px-4 py-2 text-sm rounded-md border border-gray-300 text-gray-700 hover:bg-gray-50" disabled={requestStatus === 'requesting'}>Cancel</button>
                <button type="submit" className="px-4 py-2 text-sm rounded-md bg-emerald-600 text-white hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed" disabled={requestStatus === 'requesting'}>{requestStatus === 'requesting' ? 'Sending...' : 'Send Request'}</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {showImageModal && item.user_images_urls?.length > 0 && (
        <div className="fixed inset-0 bg-black bg-opacity-90 z-50 flex items-center justify-center p-4" onClick={() => setShowImageModal(false)}>
          <button onClick={e => { e.stopPropagation(); setShowImageModal(false); }} className="absolute top-4 right-4 text-white hover:text-gray-300 z-10"><XMarkIcon className="h-8 w-8" /></button>
          <button onClick={e => { e.stopPropagation(); setCurrentImageIndex(prev => prev > 0 ? prev - 1 : item.user_images_urls.length - 1); }} className="absolute left-4 text-white hover:text-gray-300 z-10"><ChevronLeftIcon className="h-10 w-10" /></button>
          <img src={item.user_images_urls[currentImageIndex]} alt={`${itemTypeLabel} photo ${currentImageIndex + 1}`} className="max-w-full max-h-[90vh] object-contain" onClick={e => e.stopPropagation()} />
          <button onClick={e => { e.stopPropagation(); setCurrentImageIndex(prev => prev < item.user_images_urls.length - 1 ? prev + 1 : 0); }} className="absolute right-4 text-white hover:text-gray-300 z-10"><ChevronRightIcon className="h-10 w-10" /></button>
          <div className="absolute bottom-4 text-white text-sm bg-black bg-opacity-50 px-3 py-1 rounded">{currentImageIndex + 1} / {item.user_images_urls.length}</div>
        </div>
      )}
    </div>
  );
};

export default ItemDetail;
