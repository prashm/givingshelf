import React, { useState, useEffect, useCallback } from 'react';
import axios from '../../lib/axios';
import { useItems } from '../../contexts/ItemContext';
import { useAuth } from '../../contexts/AuthContext';
import FulfillWishlistItemForm from './FulfillWishlistItemForm';
import { ArrowPathIcon } from '@heroicons/react/24/outline';

const WISHLIST_STATUS = 3;

const FulfillWishlistItemPage = ({
  itemId,
  setCurrentPage,
  preservePath,
  returnPage = 'books',
  onOpenLoginModal
}) => {
  const { currentUser, loading: authLoading } = useAuth();
  const { getItem } = useItems();
  const [book, setBook] = useState(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);
  const [formData, setFormData] = useState({
    condition: 'good',
    pickup_method: '',
    pickup_address: '',
    personal_note: '',
    community_group_ids: []
  });

  const load = useCallback(async () => {
    if (!itemId) return;
    setLoading(true);
    setError(null);
    try {
      const data = await getItem(itemId);
      if (!data) {
        setBook(null);
        return;
      }
      if (data.type !== 'Book' || data.status !== WISHLIST_STATUS) {
        setError('This listing is not an open wishlist request.');
        setBook(data);
        return;
      }
      const gids = Array.isArray(data.community_group_ids) ? data.community_group_ids : [];
      const userGroups = (currentUser?.community_groups || []).map((g) => ({
        id: g.id,
        name: g.name,
        short_name: g.short_name
      }));
      setFormData((prev) => ({
        ...prev,
        community_group_ids: gids.length ? gids : userGroups.map((g) => g.id),
        pickup_method: data.pickup_method || '',
        pickup_address: data.pickup_address || '',
        personal_note: data.personal_note || '',
        condition: data.condition || 'good'
      }));
      setBook({ ...data, selectableGroups: userGroups });
    } catch (e) {
      setError('Failed to load book.');
      setBook(null);
    } finally {
      setLoading(false);
    }
  }, [itemId, getItem, currentUser?.community_groups]);

  useEffect(() => {
    if (currentUser) {
      load();
    } else {
      setLoading(false);
    }
  }, [load, currentUser]);

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => {
      const next = { ...prev, [name]: value };
      if (name === 'pickup_method' && value === 'meet_in_person') {
        next.pickup_address = '';
      }
      return next;
    });
  };

  const onToggleGroup = (groupId) => {
    const id = parseInt(groupId, 10);
    setFormData((prev) => {
      const cur = (prev.community_group_ids || []).map((x) => parseInt(x, 10));
      const s = new Set(cur);
      if (s.has(id)) s.delete(id);
      else s.add(id);
      return { ...prev, community_group_ids: [ ...s ] };
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.condition) {
      setError('Please select a condition.');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      await axios.post(
        `/api/items/${itemId}/fulfill_wishlist`,
        {
          item: {
            condition: formData.condition,
            pickup_method: formData.pickup_method || undefined,
            pickup_address: formData.pickup_address || undefined,
            personal_note: formData.personal_note || undefined,
            community_group_ids: formData.community_group_ids || []
          }
        },
        { withCredentials: true, headers: { 'Content-Type': 'application/json', Accept: 'application/json' } }
      );
      setCurrentPage(returnPage, preservePath ? { preservePath: true } : {});
    } catch (err) {
      const msg = err.response?.data?.errors;
      const text = Array.isArray(msg) ? msg.join(', ') : (err.response?.data?.error || 'Could not save.');
      setError(text);
    } finally {
      setSubmitting(false);
    }
  };

  const goBack = () => {
    setCurrentPage(returnPage, preservePath ? { preservePath: true } : {});
  };

  if (authLoading) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-2xl flex items-center justify-center text-gray-600">
        <ArrowPathIcon className="h-8 w-8 animate-spin text-emerald-600 mr-2" />
        Loading…
      </div>
    );
  }

  if (!currentUser) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-2xl text-center">
        <h2 className="text-2xl font-bold text-gray-900 mb-4">Sign in to fulfill this wish</h2>
        <button
          type="button"
          className="px-6 py-2 bg-emerald-600 text-white rounded-md"
          onClick={() => onOpenLoginModal({
            page: 'fulfillWishlistItem',
            fulfillItemId: itemId,
            afterLoginAction: { type: 'fulfillWishlist', itemId }
          })}
        >
          Sign in
        </button>
        <p className="mt-4">
          <button type="button" className="text-emerald-600 underline" onClick={goBack}>Back</button>
        </p>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-2xl flex items-center justify-center gap-2 text-gray-600">
        <ArrowPathIcon className="h-8 w-8 animate-spin text-emerald-600" />
        Loading…
      </div>
    );
  }

  if (error && !book) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-2xl">
        <p className="text-red-600">{error}</p>
        <button type="button" onClick={goBack} className="mt-4 text-emerald-600 underline">Go back</button>
      </div>
    );
  }

  if (book && (book.type !== 'Book' || book.status !== WISHLIST_STATUS)) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-2xl text-center">
        <p className="text-red-600 mb-4">{error || 'This book is not a wishlist request.'}</p>
        <button type="button" onClick={goBack} className="text-emerald-600 underline">Go back</button>
      </div>
    );
  }

  const userGroups = (currentUser?.community_groups || []).map((g) => ({
    id: g.id,
    name: g.name,
    short_name: g.short_name
  }));

  return (
    <div className="container mx-auto py-8 px-4 max-w-2xl">
      <h2 className="text-2xl font-bold text-gray-900 mb-2 text-center">Fulfill a wish</h2>
      <p className="text-sm text-gray-600 mb-6 text-center">Set condition and pickup details. Your book will be listed and the requester will be notified.</p>
      {error && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 text-red-700 rounded">{error}</div>
      )}
      <div className="bg-white rounded-lg shadow-md p-6">
        <FulfillWishlistItemForm
          book={book}
          communityGroups={userGroups}
          formData={formData}
          onInputChange={handleInputChange}
          onToggleGroup={onToggleGroup}
          onSubmit={handleSubmit}
          onCancel={goBack}
          loading={submitting}
        />
      </div>
    </div>
  );
};

export default FulfillWishlistItemPage;
