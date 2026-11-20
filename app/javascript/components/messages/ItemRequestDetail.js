import React, { useEffect, useState } from 'react';
import { fetchItemRequestDetails, updateItemRequestStatus } from '../../lib/itemRequestsApi';
import { CheckIcon, XMarkIcon, CheckCircleIcon, ArrowPathIcon } from '@heroicons/react/24/outline';
import * as Constants from '../../lib/constants';
import { CheckIcon as CheckIconSolid, XMarkIcon as XMarkIconSolid, CheckCircleIcon as CheckCircleIconSolid } from '@heroicons/react/24/solid';
import ChatSection from './ChatSection';
import RequestActionDialog, { requestActionCopy, submitRequestAction } from '../common/RequestActionDialog';

const ItemRequestDetail = ({ itemRequestId, setCurrentPage, currentUser }) => {
  const [request, setRequest] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [updatingStatus, setUpdatingStatus] = useState(false);
  const [hasMarkedAsViewed, setHasMarkedAsViewed] = useState(false);
  // The open confirm dialog: 'decline', 'cancel' or 'uncancel', or null.
  const [dialogAction, setDialogAction] = useState(null);
  const [dialogError, setDialogError] = useState('');

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
    if (actionType === 'decline') {
      openDialog('decline');
      return;
    }

    setUpdatingStatus(true);
    try {
      const updatedRequest = await updateItemRequestStatus(itemRequestId, actionType);
      setRequest(updatedRequest);
    } catch (err) {
      setError(err.response?.data?.errors?.[0] || err.response?.data?.error || 'Failed to update status. Please try again.');
    } finally {
      setUpdatingStatus(false);
    }
  };

  const openDialog = (action) => {
    setDialogError('');
    setDialogAction(action);
  };

  // Decline (owner), cancel and reopen (requester) go through the dialog, with an optional note.
  const confirmDialog = async (note) => {
    setUpdatingStatus(true);
    setDialogError('');
    try {
      const updatedRequest = await submitRequestAction(itemRequestId, dialogAction, note);
      setRequest(updatedRequest);
      setDialogAction(null);
    } catch (err) {
      setDialogError(err.response?.data?.errors?.[0] || err.response?.data?.error || 'Something went wrong. Please try again.');
    } finally {
      setUpdatingStatus(false);
    }
  };

  // A status change arrived in the thread (e.g. the other party cancelled): refresh the request.
  const refreshRequest = async () => {
    try {
      setRequest(await fetchItemRequestDetails(itemRequestId));
    } catch (err) {
      console.error('Failed to refresh request:', err);
    }
  };

  const itemData = request?.book || request?.toy;
  const isOwner = currentUser && itemData?.owner?.id === currentUser.id;
  const currentStatusDisplay = request?.status_display;
  // A wish no one has offered yet: its actions use the wish wording, as on the wish's own page.
  const isOpenWish = Boolean(itemData?.wishlist_item) && !itemData?.owner;
  const cancelCopy = requestActionCopy('cancel', { isWish: isOpenWish });
  const reopenCopy = requestActionCopy('uncancel', { isWish: isOpenWish });

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
    const isFinished = ['Completed', 'Declined', 'Cancelled'].includes(currentStatusDisplay);
    const tooltip = !request.can_update_status
      ? (isFinished ? `This request is already ${currentStatusDisplay.toLowerCase()}` : 'Another request for this item is already accepted')
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
            Back to My Item Requests
          </button>
        </div>
      </div>
    );
  }

  const closedNotice = (() => {
    if (request.message_thread_writable) return null;
    // Cancelled comes first: a cancelled wish has no owner either, but its requester won't hear
    // about offers until they reopen it.
    if (currentStatusDisplay === 'Cancelled') {
      if (isOwner) return 'The requester cancelled this request, so the conversation is read-only.';
      return itemData?.owner
        ? 'You cancelled this request. Reopen it to send messages again.'
        : "You cancelled this request. Reopen it if you'd still like this item, and you'll be emailed when someone offers it.";
    }
    if (!itemData?.owner) {
      return "No one has offered this item yet. You'll be emailed when someone does, and you can message them here.";
    }
    return `This request is ${String(currentStatusDisplay || 'closed').toLowerCase()}, so the conversation is read-only.`;
  })();
  const createdAt = new Date(request.created_at).toLocaleString();
  const updatedAt = new Date(request.updated_at).toLocaleString();
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
            Back to My Item Requests
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
              {item?.deleted ? (
                <p className="text-sm text-gray-500 mt-1">This item was removed by its owner.</p>
              ) : (
              <>
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
              </>
              )}
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

        <section className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm text-gray-700">
          <div>
            <p className="font-medium text-gray-500">Requested at</p>
            <p>{createdAt}</p>
            {isOwner && currentStatusDisplay === 'Cancelled' && request.updated_at && (
              <p className="mt-2 text-gray-600 bold">
                <strong>User canceled request at {updatedAt}</strong>
              </p>
            )}
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
              <div className="space-y-2">
                <div className="flex items-center gap-2 flex-wrap">
                  <p className="font-medium text-gray-500">Status</p>
                  <p className="capitalize">{request.status_display || 'Pending'}</p>
                  {request.can_cancel && (
                    <button
                      type="button"
                      onClick={() => openDialog('cancel')}
                      disabled={updatingStatus}
                      className="flex items-center gap-1.5 px-3 py-2 rounded-md text-sm font-medium transition-colors bg-gray-100 text-gray-700 hover:bg-gray-200 disabled:opacity-50 disabled:cursor-not-allowed"
                      title={cancelCopy.title}
                    >
                      <XMarkIcon className="w-4 h-4" />
                      <span>{cancelCopy.buttonLabel}</span>
                    </button>
                  )}
                  {request.can_uncancel && (
                    <button
                      type="button"
                      onClick={() => openDialog('uncancel')}
                      disabled={updatingStatus}
                      className="flex items-center gap-1.5 px-3 py-2 rounded-md text-sm font-medium bg-gray-100 text-gray-700 hover:bg-emerald-100 hover:text-emerald-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                      title={reopenCopy.title}
                    >
                      <ArrowPathIcon className="w-4 h-4" />
                      <span>{reopenCopy.buttonLabel}</span>
                    </button>
                  )}
                </div>
              </div>
            )}
          </div>
        </section>
      </div>

      {/* The thread: messages and status changes. Read-only when there's nobody to message yet
          (an open wish) or the request is finished or cancelled. */}
      {currentUser && (
        <ChatSection
          itemRequestId={itemRequestId}
          currentUser={currentUser}
          otherUser={currentUser.id === request.requester.id ? item?.owner : request.requester}
          writable={Boolean(request.message_thread_writable)}
          closedNotice={closedNotice}
          onEvent={refreshRequest}
        />
      )}

      <RequestActionDialog
        action={dialogAction}
        isWish={isOpenWish}
        busy={updatingStatus}
        error={dialogError}
        onConfirm={confirmDialog}
        onClose={() => setDialogAction(null)}
      />
    </div>
  );
};

export default ItemRequestDetail;
