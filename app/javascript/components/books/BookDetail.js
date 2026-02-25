import React from 'react';
import { BookOpenIcon, CalendarIcon } from '@heroicons/react/24/outline';
import ItemDetail from '../items/ItemDetail';

const BOOK_CONFIG = {
  itemTypeLabel: 'Book',
  getSubtitle: (item) => item.author ? `by ${item.author}` : null,
  getDetailFields: (item) => [
    { icon: BookOpenIcon, label: 'Genre', value: item.genre },
    { icon: CalendarIcon, label: 'Published', value: item.published_year },
    { label: 'ISBN', value: item.isbn }
  ],
  donateSimilarLabel: 'Donate a Similar Book',
  donateLabel: 'Donate a Book',
  browseMoreLabel: 'Browse More Books',
  requestLabel: 'Request This Book',
  editLabel: 'Edit This Book',
  notFoundLabel: 'Book Not Found',
  emptyPlaceholder: '📖',
  requestModalTitle: 'Request this book',
  requestModalDescription: "Add a short message to the donor explaining why you'd like this book or how you plan to pick it up.",
  DetailIcon: BookOpenIcon
};

const BookDetail = ({ book, setCurrentPage, currentUser, onEditBook, onOpenLoginModal, setRedirectReason, sourcePage, groupBrowseItemType }) => (
  <ItemDetail
    item={book}
    setCurrentPage={setCurrentPage}
    currentUser={currentUser}
    onEditItem={onEditBook}
    onOpenLoginModal={onOpenLoginModal}
    setRedirectReason={setRedirectReason}
    sourcePage={sourcePage}
    groupBrowseItemType={groupBrowseItemType}
    config={BOOK_CONFIG}
  />
);

export default BookDetail;
