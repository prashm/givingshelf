import React from 'react';
import * as Constants from '../../lib/constants';

const ItemFulfillmentFields = ({
  formData,
  validationErrors = {},
  onInputChange,
  communityGroups = [],
  updateFormData,
  onToggleGroup,
  conditionLabel = 'Condition',
  shareLabel = 'Share this item in',
  shareHelpText = 'This item will only be shared in the groups you select.',
  pickupAddressPlaceholder = 'Enter the address for pickup',
  excludePickupMethods = [],
  isToy = false,
  hidePickupAddressForMeetInPerson = false,
}) => {
  const pickupMethodOptions = [
    { value: 'meet_in_person', label: 'Meet in person' },
    { value: 'pickup_little_library_drop', label: 'Pickup little library drop' },
    { value: 'pickup_porch_drop', label: 'Pickup porch drop' },
  ].filter((opt) => !excludePickupMethods.includes(opt.value));

  const selectedGroupIds = Array.isArray(formData.community_group_ids)
    ? formData.community_group_ids.map((id) => parseInt(id, 10)).filter((id) => Number.isFinite(id))
    : [];

  const sortedGroups = Array.isArray(communityGroups)
    ? [...communityGroups].sort((a, b) => {
      const aZip = a?.short_name === Constants.ZIPCODE_SHORT_NAME;
      const bZip = b?.short_name === Constants.ZIPCODE_SHORT_NAME;
      if (aZip && !bZip) return -1;
      if (!aZip && bZip) return 1;
      return String(a?.name || '').localeCompare(String(b?.name || ''));
    })
    : [];

  const toggleGroup = (groupId) => {
    if (onToggleGroup) {
      onToggleGroup(groupId);
      return;
    }
    if (!updateFormData) return;

    const id = parseInt(groupId, 10);
    if (!Number.isFinite(id)) return;

    const has = selectedGroupIds.includes(id);
    const next = has ? selectedGroupIds.filter((x) => x !== id) : [...selectedGroupIds, id];
    updateFormData({ community_group_ids: next });
  };

  const showPickupAddress = Boolean(formData.pickup_method) && (
    !hidePickupAddressForMeetInPerson || formData.pickup_method !== 'meet_in_person'
  );

  return (
    <>
      {/* Group availability */}
      {sortedGroups.length > 0 && (updateFormData || onToggleGroup) && (
        <div className="mt-4 mb-2">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            {shareLabel}
          </label>
          <div className="border border-gray-200 rounded-md p-3 max-h-52 overflow-auto space-y-2">
            {sortedGroups.map((g) => (
              <label key={g.id} className="flex items-center gap-2 text-sm text-gray-800">
                <input
                  type="checkbox"
                  checked={selectedGroupIds.includes(g.id)}
                  onChange={() => toggleGroup(g.id)}
                  style={{
                    appearance: 'auto',
                    WebkitAppearance: 'auto',
                    accentColor: 'rgb(5, 150, 105)',
                    width: '1rem',
                    height: '1rem',
                    cursor: 'pointer',
                    marginTop: 0,
                    marginRight: '0.5rem'
                  }}
                />
                <span>{g.name}</span>
                {g.short_name === Constants.ZIPCODE_SHORT_NAME && (
                  <span className="text-xs text-gray-500">(default)</span>
                )}
              </label>
            ))}
          </div>
          <p className="mt-2 text-xs text-gray-500">
            {shareHelpText}
          </p>
        </div>
      )}

      {/* Condition */}
      <div className="mt-4 mb-2">
        <label htmlFor="condition" className="block text-sm font-medium text-gray-700 mb-2">
          {conditionLabel} *
        </label>
        <select
          id="condition"
          name="condition"
          value={formData.condition || 'good'}
          onChange={onInputChange}
          className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
          style={{ appearance: 'auto' }}
        >
          <option value="excellent">Excellent - Like new, minimal wear</option>
          <option value="good">Good - Light wear, still in good shape</option>
          <option value="fair">
            Fair - Moderate wear, {isToy ? 'playable' : 'readable'} condition
          </option>
          <option value="poor">Poor - Heavy wear, may have damage</option>
        </select>
        {validationErrors.condition && (
          <p className="mt-1 text-sm font-semibold text-red-600 bg-red-50 px-2 py-1 rounded">
            {validationErrors.condition}
          </p>
        )}
      </div>

      {/* Personal Note */}
      <div className="mt-4 mb-2">
        <label htmlFor="personal_note" className="block text-sm font-medium text-gray-700 mb-2">
          Personal Note (Optional)
        </label>
        <textarea
          id="personal_note"
          name="personal_note"
          value={formData.personal_note || ''}
          onChange={onInputChange}
          rows={4}
          className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
          placeholder="write a note or short story about what this item meant to you..."
        />
      </div>

      {/* Pickup Method */}
      <div className="mt-4 mb-2">
        <label htmlFor="pickup_method" className="block text-sm font-medium text-gray-700 mb-2">
          Pickup Method
        </label>
        <select
          id="pickup_method"
          name="pickup_method"
          value={formData.pickup_method || ''}
          onChange={(e) => {
            onInputChange(e);
            if (e.target.value === 'meet_in_person') {
              if (updateFormData) {
                updateFormData({ pickup_address: '' });
              } else {
                onInputChange({ target: { name: 'pickup_address', value: '' } });
              }
            }
          }}
          className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
          style={{ appearance: 'auto' }}
        >
          <option value="">Select pickup method...</option>
          {pickupMethodOptions.map((opt) => (
            <option key={opt.value} value={opt.value}>{opt.label}</option>
          ))}
        </select>
      </div>

      {/* Pickup Address - Conditional */}
      {showPickupAddress && (
        <div>
          <label htmlFor="pickup_address" className="block text-sm font-medium text-gray-700 mb-2">
            Pickup Address
          </label>
          {formData.pickup_method === 'pickup_little_library_drop' && (
            <div className="mb-2">
              <a
                href="https://app.littlefreelibrary.org/ourmap"
                target="_blank"
                rel="noopener noreferrer"
                className="text-sm text-emerald-600 hover:text-emerald-700 underline"
              >
                Find a Little Free Library near you
              </a>
            </div>
          )}
          <textarea
            id="pickup_address"
            name="pickup_address"
            value={formData.pickup_address || ''}
            onChange={onInputChange}
            rows={3}
            className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            placeholder={pickupAddressPlaceholder}
          />
        </div>
      )}

      <div className="mt-6 p-4 bg-amber-50 border border-amber-200 rounded-md">
        <p className="text-sm text-amber-800">
          <strong>Safety reminder:</strong> Your address will be shared with other signed-in users if you add it here. If you prefer more privacy, skip entering an address; you can arrange a meeting or pickup through the in-app chat instead.
        </p>
      </div>
    </>
  );
};

export default ItemFulfillmentFields;
