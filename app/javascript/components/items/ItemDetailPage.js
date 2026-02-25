import React, { useState, useEffect } from 'react';
import { useItems } from '../../contexts/ItemContext';
import BookDetail from '../books/BookDetail';
import ToyDetail from '../toys/ToyDetail';
import { parsePageFromPath } from '../../lib/textUtils';
import * as Constants from '../../lib/constants';

const getHintFromUrl = () => {
  if (typeof window === 'undefined') return null;
  const parsed = parsePageFromPath(window.location.pathname);
  return parsed.itemType || null;
};

const inferItemType = (item, hint) => {
  if (!item) return hint === Constants.ITEM_TYPE_TOY ? 'toy' : 'book';
  if (item.type === Constants.ITEM_TYPE_TOY) return 'toy';
  if (item.type === Constants.ITEM_TYPE_BOOK) return 'book';
  if (item.brand != null || item.age_range != null) return 'toy';
  if (item.author != null || item.genre != null || item.isbn != null) return 'book';
  return hint === Constants.ITEM_TYPE_TOY ? 'toy' : 'book';
};

/**
 * ItemDetailPage fetches the full item via API and uses the `type` field in the response
 * to render BookDetail or ToyDetail accordingly. Uses hintItemType when type/fields are ambiguous.
 */
const ItemDetailPage = ({
  selectedItem,
  hintItemType,
  setCurrentPage,
  currentUser,
  onEditBook,
  onEditToy,
  onOpenLoginModal,
  setRedirectReason,
  sourcePage,
  groupBrowseItemType
}) => {
  const { getItem } = useItems();
  const [resolvedItem, setResolvedItem] = useState(null);
  const [itemType, setItemType] = useState(null); // 'book' | 'toy'
  const [loading, setLoading] = useState(true);
  const urlHint = getHintFromUrl();
  const effectiveHint = sourcePage === 'myItems'
    ? (hintItemType ?? null)
    : (hintItemType ?? urlHint);

  useEffect(() => {
    if (!selectedItem?.id) {
      setResolvedItem(null);
      setItemType(null);
      setLoading(false);
      return;
    }

    setLoading(true);
    getItem(selectedItem.id)
      .then((data) => {
        if (!data) {
          setResolvedItem(null);
          setItemType(null);
          return;
        }
        setResolvedItem(data);
        setItemType(inferItemType(data, effectiveHint));
      })
      .catch(() => {
        setResolvedItem(null);
        setItemType(null);
      })
      .finally(() => setLoading(false));
  }, [selectedItem?.id, getItem, effectiveHint]);

  // Sync with prop when selectedItem changes (e.g. from history restore)
  useEffect(() => {
    if (selectedItem && !resolvedItem && !loading) {
      setResolvedItem(selectedItem);
      setItemType(inferItemType(selectedItem, effectiveHint));
    }
  }, [selectedItem, resolvedItem, loading, effectiveHint]);

  if (loading) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-4xl">
        <div className="bg-white rounded-lg shadow-md p-6 flex items-center justify-center min-h-[200px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-emerald-600 mx-auto mb-4" />
            <p className="text-gray-600">Loading...</p>
          </div>
        </div>
      </div>
    );
  }

  const commonProps = {
    setCurrentPage,
    currentUser,
    onOpenLoginModal,
    setRedirectReason,
    sourcePage,
    groupBrowseItemType
  };

  if (itemType === 'toy') {
    return (
      <ToyDetail
        toy={resolvedItem}
        {...commonProps}
        onEditToy={onEditToy}
      />
    );
  }

  return (
    <BookDetail
      book={resolvedItem}
      {...commonProps}
      onEditBook={onEditBook}
    />
  );
};

export default ItemDetailPage;
