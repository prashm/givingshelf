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
    case 'closed_out':
    case 'moved': return message.content;
    default: return 'The request was updated';
  }
};

// Whether the event's note is shown under its wording (the close-out events' wording is the note).
export const eventShowsNote = (message) =>
  Boolean(message.content) && !['closed_out', 'moved'].includes(message.event);

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
