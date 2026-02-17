import React, { useEffect, useState } from 'react';
import { fetchItemRequestDetails, updateItemRequestStatus } from '../../lib/itemRequestsApi';
import { CheckIcon, XMarkIcon, CheckCircleIcon } from '@heroicons/react/24/outline';
import * as Constants from '../../lib/constants';
import { CheckIcon as CheckIconSolid, XMarkIcon as XMarkIconSolid, CheckCircleIcon as CheckCircleIconSolid } from '@heroicons/react/24/solid';
import ChatSection from './ChatSection';

const ItemRequestDetail = ({ itemRequestId, setCurrentPage, currentUser }) => {
  const [request, setRequest] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [updatingStatus, setUpdatingStatus] = useState(false);
  const [hasMarkedAsViewed, setHasMarkedAsViewed] = useState(false);

  useEffect(() => {
    if (!itemRequestId) {
      setError('Missing item request id.');
      setLoading(false);
      return;
    }

    const loadDetails = async () => {
      setLoading(true);
      setError(null);
      try {
        const data = await fetchItemRequestDetails(itemRequestId);
        setRequest(data);
      } catch (err) {
        setError(err.response?.data?.error || 'Failed to load request details.');
      } finally {
        setLoading(false);
      }
    };

    loadDetails();
    setHasMarkedAsViewed(false); // Reset when itemRequestId changes
  }, [itemRequestId]);

  // Mark request as viewed when owner views a pending request
  useEffect(() => {
    if (!request || !currentUser || updatingStatus || hasMarkedAsViewed) return;

    const itemData = request.book || request.toy;
    const isOwner = currentUser.id === itemData?.owner?.id;
    const isPending = request?.status_display === 'Pending';

    if (isOwner && isPending) {
      setHasMarkedAsViewed(true);
      const markAsViewed = async () => {
        setUpdatingStatus(true);
        try {
          const updatedRequest = await updateItemRequestStatus(itemRequestId, 'mark_as_viewed');
          setRequest(updatedRequest);
        } catch (err) {
          // Silently fail - don't show error for auto-marking as viewed
          console.error('Failed to mark request as viewed:', err);
        } finally {
          setUpdatingStatus(false);
        }
      };
      markAsViewed();
    }
  }, [request, currentUser, updatingStatus, hasMarkedAsViewed, itemRequestId]);

  const handleStatusUpdate = async (actionType) => {
    if (updatingStatus) return;

    setUpdatingStatus(true);
    try {
      const updatedRequest = await updateItemRequestStatus(itemRequestId, actionType);
      setRequest(updatedRequest);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to update status. Please try again.');
    } finally {
      setUpdatingStatus(false);
    }
  };

  const itemData = request?.book || request?.toy;
  const isOwner = currentUser && itemData?.owner?.id === currentUser.id;
  const currentStatusDisplay = request?.status_display;

  const statusButtons = [
    {
      action: 'accept',
      label: 'Accept',
      statusMatch: 'Accepted',
      activeColor: 'bg-emerald-600',
      Icon: CheckIcon,
      IconSolid: CheckIconSolid,
      title: 'Accept Request',
      additionalDisabled: currentStatusDisplay === 'Accepted',
      description: 'Approve this request and mark the item as requested'
    },
    {
      action: 'decline',
      label: 'Decline',
      statusMatch: 'Declined',
      activeColor: 'bg-red-600',
      Icon: XMarkIcon,
      IconSolid: XMarkIconSolid,
      title: 'Decline Request',
      additionalDisabled: false,
      description: 'Reject this request'
    },
    {
      action: 'complete',
      label: 'Complete',
      statusMatch: 'Completed',
      activeColor: 'bg-blue-600',
      Icon: CheckCircleIcon,
      IconSolid: CheckCircleIconSolid,
      title: 'Mark as Completed',
      additionalDisabled: currentStatusDisplay !== 'Accepted',
      description: 'This action will mark the item as "donated" (only available for accepted requests)'
    }
  ];

  const renderStatusButton = (buttonConfig) => {
    const isActive = currentStatusDisplay === buttonConfig.statusMatch;
    const isDisabled = updatingStatus || !request.can_update_status || buttonConfig.additionalDisabled;
    const tooltip = !request.can_update_status
      ? 'Another request for this item is already accepted'
      : isActive && buttonConfig.action === 'accept'
      ? 'This request is already accepted'
      : buttonConfig.title;

    return (
      <button
        key={buttonConfig.action}
        type="button"
        onClick={() => handleStatusUpdate(buttonConfig.action)}
        disabled={isDisabled}
        className={`flex items-center gap-1.5 px-3 py-2 rounded-md text-sm font-medium transition-colors ${
          isActive
            ? `${buttonConfig.activeColor} text-white shadow-md`
            : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
        } disabled:opacity-50 disabled:cursor-not-allowed`}
        title={tooltip}
      >
        {isActive ? (
          <buttonConfig.IconSolid className="w-4 h-4" />
        ) : (
          <buttonConfig.Icon className="w-4 h-4" />
        )}
        <span>{buttonConfig.label}</span>
      </button>
    );
  };

  if (loading) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-3xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <p className="text-sm text-gray-500">Loading request details...</p>
        </div>
      </div>
    );
  }

  if (error || !request) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-3xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <p className="text-sm text-red-600 mb-4">
            {error || 'Unable to load this request.'}
          </p>
          <button
            type="button"
            onClick={() => setCurrentPage('messages')}
            className="px-4 py-2 text-sm rounded-md bg-emerald-600 text-white hover:bg-emerald-700"
          >
            Back to Messages
          </button>
        </div>
      </div>
    );
  }

  const createdAt = new Date(request.created_at).toLocaleString();
  const item = request.book || request.toy;
  const itemLabel = request.book ? 'Book' : 'Item';
  const itemTitle = item?.title;
  const itemSubtitle = request.book ? `by ${item?.author}` : item?.brand ? `(${item.brand})` : '';

  return (
    <div className="container mx-auto py-8 px-4 max-w-3xl">
      <div className="bg-white rounded-lg shadow-md p-6 space-y-6">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-bold text-gray-900">Item Request Details</h2>
          <button
            type="button"
            onClick={() => setCurrentPage('messages')}
            className="text-sm text-emerald-700 hover:text-emerald-900"
          >
            Back to Messages
          </button>
        </div>

        <section>
          <h3 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-2">
            {itemLabel}
          </h3>
          <div className="flex items-start justify-between">
            <div>
              <p className="text-lg font-medium text-gray-900">{itemTitle}</p>
              {itemSubtitle && <p className="text-sm text-gray-600">{itemSubtitle}</p>}
              <p className="text-sm text-gray-500 mt-1">
                Status: <span className="font-medium capitalize">{item?.status_display}</span>
              </p>
              <button
                type="button"
                onClick={() =>
                  setCurrentPage('itemDetails', {
                    selectedBook: item,
                    itemDetailSource: 'messages',
                    selectedItemType: request.book ? Constants.ITEM_TYPE_BOOK : Constants.ITEM_TYPE_TOY
                  })
                }
                className="mt-2 text-sm text-emerald-700 hover:text-emerald-900 underline"
              >
                View {itemLabel.toLowerCase()} details
              </button>
            </div>
          </div>
        </section>

        <section>
          <h3 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-2">
            Requester
          </h3>
          <div className="space-y-1 text-sm text-gray-800">
            <p className="font-medium">{request.requester.name}</p>
            <p className="text-gray-600">{request.requester.location}</p>
          </div>
        </section>

        <section>
          <h3 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-2">
            Message
          </h3>
          <p className="text-sm text-gray-800 whitespace-pre-line">
            {request.message}
          </p>
        </section>

        <section className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm text-gray-700">
          <div>
            <p className="font-medium text-gray-500">Requested at</p>
            <p>{createdAt}</p>
          </div>
          <div>
            {isOwner ? (
              <div className="space-y-3">
                <div className="flex gap-2 flex-wrap">
                  {statusButtons.map(renderStatusButton)}
                </div>
                <div className="text-xs text-gray-500 space-y-1">
                  {statusButtons.map(btn => (
                    <p key={btn.action}>
                      • <strong>{btn.label}:</strong> {btn.description}
                    </p>
                  ))}
                </div>
              </div>
            ) : (
              <>
                <p className="font-medium text-gray-500">Status</p>
                <p className="capitalize">{request.status_display || 'Pending'}</p>
              </>
            )}
          </div>
        </section>
      </div>

      {/* Chat Section */}
      {currentUser && (
        <ChatSection
          itemRequestId={itemRequestId}
          currentUser={currentUser}
          otherUser={
            currentUser.id === request.requester.id
              ? item?.owner
              : request.requester
          }
        />
      )}
    </div>
  );
};

export default ItemRequestDetail;
