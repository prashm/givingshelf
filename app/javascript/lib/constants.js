export const ZIPCODE_SHORT_NAME = 'zipcode';

export const ITEM_TYPE_BOOK = 'Book';
export const ITEM_TYPE_TOY = 'Toy';

// Status names the API returns (the Rails enum keys on Item and ItemRequest).
export const ITEM_STATUS = Object.freeze({
  AVAILABLE: 'available',
  REQUESTED: 'requested',
  DONATED: 'donated',
  WISHLIST: 'wishlist'
});

export const REQUEST_STATUS = Object.freeze({
  PENDING: 'pending',
  ACCEPTED: 'accepted',
  DECLINED: 'declined',
  IN_REVIEW: 'in_review',
  COMPLETED: 'completed',
  CANCELLED: 'cancelled'
});
