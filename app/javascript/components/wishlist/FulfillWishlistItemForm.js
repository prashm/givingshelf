import React from 'react';
import ItemFulfillmentFields from '../common/ItemFulfillmentFields';

const FulfillWishlistItemForm = ({
  book,
  communityGroups = [],
  formData,
  validationErrors = {},
  onInputChange,
  onToggleGroup,
  onSubmit,
  onCancel,
  loading = false
}) => {
  return (
    <form onSubmit={onSubmit} className="space-y-6">
      {book && (
        <div className="flex flex-col sm:flex-row gap-4 p-4 bg-gray-50 rounded-lg border border-gray-200">
          {book.cover_image_url && (
            <img
              src={book.cover_image_url}
              alt=""
              className="w-16 h-24 object-cover rounded border mx-auto sm:mx-0"
            />
          )}
          <div className="min-w-0 text-center sm:text-left">
            <h3 className="text-lg font-semibold text-gray-900">{book.title}</h3>
            {book.author && <p className="text-sm text-gray-600">by {book.author}</p>}
          </div>
        </div>
      )}

      <ItemFulfillmentFields
        formData={formData}
        validationErrors={validationErrors}
        onInputChange={onInputChange}
        communityGroups={communityGroups}
        onToggleGroup={onToggleGroup}
        conditionLabel="Condition"
        shareLabel="Share this item in"
        shareHelpText="This item will only be shared in the groups you select."
        pickupAddressPlaceholder="Where readers can pick up (optional in many cases)"
        hidePickupAddressForMeetInPerson={true}
      />

      <div className="flex gap-3 pt-2">
        {onCancel && (
          <button
            type="button"
            onClick={onCancel}
            className="flex-1 py-2 border border-gray-300 rounded-md text-gray-700 bg-white hover:bg-gray-50"
          >
            Cancel
          </button>
        )}
        <button
          type="submit"
          disabled={loading}
          className="flex-1 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700 disabled:opacity-50"
        >
          {loading ? 'Saving…' : 'Save & list book'}
        </button>
      </div>
    </form>
  );
};

export default FulfillWishlistItemForm;
