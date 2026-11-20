import React from 'react';
import ReasonDialog from './ReasonDialog';
import { cancelItemRequest, updateItemRequestStatus } from '../../lib/itemRequestsApi';

// The wording for each action someone takes on a request: the button that starts it and the
// dialog that confirms it. Every page that offers an action reads it from here, so the same action
// reads the same wherever it's taken.
//
// A wish with no donor yet uses the wish wording: the requester is waiting for anyone to offer the
// item, not asking a particular owner. Actions with no wish wording fall back to the request one.
const COPY = {
  request: {
    decline: {
      buttonLabel: 'Decline',
      title: 'Decline this request?',
      description: "The requester will see that you declined. You can tell them why; it's optional.",
      noteLabel: 'Reason (optional)',
      confirmLabel: 'Decline request',
      tone: 'danger'
    },
    cancel: {
      buttonLabel: 'Cancel request',
      title: 'Cancel your request?',
      description: 'The owner will see that you cancelled. You can reopen it later while the item is still available.',
      noteLabel: 'Reason (optional)',
      confirmLabel: 'Cancel request',
      tone: 'danger'
    },
    uncancel: {
      buttonLabel: 'Reopen request',
      title: 'Reopen your request?',
      description: 'The owner will see it as pending again.',
      noteLabel: 'Note for the owner (optional)',
      confirmLabel: 'Reopen request',
      tone: 'primary'
    }
  },
  wish: {
    cancel: {
      buttonLabel: 'Cancel my wish',
      title: 'Cancel your wish?',
      description: "You'll stop waiting for this item. You can reopen your wish later while it's still open.",
      noteLabel: 'Reason (optional)',
      confirmLabel: 'Cancel my wish',
      tone: 'danger'
    },
    uncancel: {
      buttonLabel: 'Reopen my wish',
      title: 'Reopen your wish?',
      description: "You'll be back on the list of members waiting for this item.",
      noteLabel: 'Note (optional)',
      confirmLabel: 'Reopen my wish',
      tone: 'primary'
    }
  }
};

// The wording for `action` ('decline', 'cancel' or 'uncancel'), or null for any other action.
export const requestActionCopy = (action, { isWish = false } = {}) =>
  (isWish && COPY.wish[action]) || COPY.request[action] || null;

// Sends the action, with the optional note, to the server. Resolves to the updated request.
export const submitRequestAction = (requestId, action, note) =>
  action === 'cancel'
    ? cancelItemRequest(requestId, note)
    : updateItemRequestStatus(requestId, action, note);

// The confirm dialog for an action. It's open while `action` is set.
const RequestActionDialog = ({ action, isWish = false, busy = false, error = '', onConfirm, onClose }) => {
  const { buttonLabel, ...dialogCopy } = requestActionCopy(action, { isWish }) || {};
  return (
    <ReasonDialog
      open={Boolean(action)}
      {...dialogCopy}
      busy={busy}
      error={error}
      onConfirm={onConfirm}
      onClose={onClose}
    />
  );
};

export default RequestActionDialog;
