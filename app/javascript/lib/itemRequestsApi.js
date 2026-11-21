import axios from '../lib/axios';

export const fetchItemRequests = async (type) => {
  const response = await axios.get('/api/item_requests', {
    params: { type },
    withCredentials: true,
  });
  return response.data;
};

export const fetchItemRequestDetails = async (id) => {
  const response = await axios.get(`/api/item_requests/${id}`, {
    withCredentials: true,
  });
  return response.data;
};

export const fetchChatMessages = async (itemRequestId) => {
  const response = await axios.get(`/api/item_requests/${itemRequestId}/messages`, {
    withCredentials: true,
  });
  return response.data.messages || [];
};

// Wording for a status-change event in the thread, from the viewer's side. `event` comes from the
// server (ItemRequestService.event_kind). The two close-out events read as their fixed note.
export const describeRequestEvent = (message, currentUserId) => {
  const mine = message.user_id === currentUserId;
  const who = mine ? 'You' : message.user_name;
  const yours = mine ? 'the' : 'your';
  switch (message.event) {
    case 'requested': return mine ? 'You sent the request' : `${who} sent a request`;
    case 'reopened': return `${who} reopened the request`;
    case 'viewed': return `${who} viewed ${yours} request`;
    case 'donor_found': return mine ? 'You offered to fulfill this wish' : `${who} offered to fulfill your wish`;
    case 'accepted': return `${who} accepted ${yours} request`;
    case 'declined': return `${who} declined ${yours} request`;
    case 'completed': return `${who} marked the handoff as complete`;
    case 'cancelled': return `${who} cancelled the request`;
    case 'item_removed':
    case 'closed_out':
    case 'moved': return fixedEventText(message);
    default: return 'The request was updated';
  }
};

// Close-out events carry a fixed text as their wording, and the person's own note, if any, as a
// second paragraph after it.
const FIXED_TEXT_EVENTS = ['item_removed', 'closed_out', 'moved'];
const fixedEventText = (message) => (message.content || '').split('\n\n')[0];

// The note shown under an event's wording, or null: whatever the person typed with the change.
export const eventNote = (message) => {
  if (!message.content) return null;
  if (!FIXED_TEXT_EVENTS.includes(message.event)) return message.content;
  const rest = message.content.split('\n\n').slice(1).join('\n\n');
  return rest || null;
};

// note: optional text shown under the status change in the request's thread.
export const updateItemRequestStatus = async (itemRequestId, actionType, note = null) => {
  const response = await axios.patch(`/api/item_requests/${itemRequestId}`, {
    action_type: actionType,
    ...(note ? { note } : {})
  }, {
    withCredentials: true,
  });
  return response.data;
};

export const cancelItemRequest = async (itemRequestId, note = null) => {
  const response = await axios.delete(`/api/item_requests/${itemRequestId}`, {
    params: note ? { note } : {},
    withCredentials: true,
  });
  return response.data;
};
