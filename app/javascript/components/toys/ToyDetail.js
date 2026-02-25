import React from 'react';
import { GiftIcon } from '@heroicons/react/24/outline';
import ItemDetail from '../items/ItemDetail';

const TOY_CONFIG = {
  itemTypeLabel: 'Toy',
  getSubtitle: (item) => [item.brand, item.age_range].filter(Boolean).join(' • ') || null,
  getDetailFields: (item) => [
    { label: 'Brand', value: item.brand },
    { label: 'Age Range', value: item.age_range }
  ],
  donateSimilarLabel: '',
  donateLabel: 'Donate a Toy',
  browseMoreLabel: 'Browse More Toys',
  requestLabel: 'Request This Toy',
  editLabel: 'Edit This Toy',
  notFoundLabel: 'Toy Not Found',
  emptyPlaceholder: '🧸',
  emptyPlaceholderIcon: GiftIcon,
  emptyStateText: 'No Image Available',
  requestModalTitle: 'Request this toy',
  requestModalDescription: "Add a short message to the donor explaining why you'd like this toy or how you plan to pick it up.",
  DetailIcon: GiftIcon
};

const ToyDetail = ({ toy, setCurrentPage, currentUser, onEditToy, onOpenLoginModal, setRedirectReason, sourcePage, groupBrowseItemType }) => (
  <ItemDetail
    item={toy}
    setCurrentPage={setCurrentPage}
    currentUser={currentUser}
    onEditItem={onEditToy}
    onOpenLoginModal={onOpenLoginModal}
    setRedirectReason={setRedirectReason}
    sourcePage={sourcePage}
    groupBrowseItemType={groupBrowseItemType}
    config={TOY_CONFIG}
  />
);

export default ToyDetail;
