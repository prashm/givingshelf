import React from 'react';
import ItemForm from './ItemForm';

const ToyForm = ({
  formData,
  validationErrors,
  onInputChange,
  updateFormData,
  communityGroups = [],
  existingUserImages = [],
  onCropUserImage,
  onCropExistingImage,
  onRemoveExistingImage,
  ageRangeHint = '',
  bucketLabels = [],
  onAgeRangeBlur,
}) => {
  return (
    <ItemForm
      formData={formData}
      validationErrors={validationErrors}
      onInputChange={onInputChange}
      updateFormData={updateFormData}
      communityGroups={communityGroups}
      maxImages={10}
      existingUserImages={existingUserImages}
      onCropUserImage={onCropUserImage}
      onCropExistingImage={onCropExistingImage}
      onRemoveExistingImage={onRemoveExistingImage}
      summaryLabel="Description"
      summaryPlaceholder="Describe the toy (10-1000 characters)"
      conditionLabel="Toy Condition"
      shareLabel="Share this toy in"
      shareHelpText="This toy will only be shared in the groups you select."
      pickupAddressPlaceholder="Enter the address for pickup"
      excludePickupMethods={['pickup_little_library_drop']}
      isToy={true}
      renderTypeSpecificFields={() => (
        <>
          {/* Brand */}
          <div>
            <label htmlFor="brand" className="block text-sm font-medium text-gray-700 mb-2">
              Brand (Optional)
            </label>
            <input
              type="text"
              id="brand"
              name="brand"
              value={formData.brand || ''}
              onChange={onInputChange}
              className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              placeholder="e.g., LEGO, Fisher-Price"
            />
          </div>

          {/* Age Range */}
          <div>
            <label htmlFor="age_range" className="block text-sm font-medium text-gray-700 mb-2">
              Age Range (Optional)
            </label>
            <input
              type="text"
              id="age_range"
              name="age_range"
              value={formData.age_range || ''}
              onChange={onInputChange}
              onBlur={onAgeRangeBlur}
              className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${
                validationErrors.age_range ? 'border-red-400' : 'border-gray-300'
              }`}
              placeholder={ageRangeHint ? `As shown on packaging (${ageRangeHint})` : 'As shown on packaging'}
            />
            {validationErrors.age_range ? (
              <p className="mt-1 text-sm text-red-600">{validationErrors.age_range}</p>
            ) : (
              ageRangeHint && <p className="mt-1 text-xs text-gray-500">{ageRangeHint}</p>
            )}
            {bucketLabels.length > 0 && (
              <div className="mt-2 flex flex-wrap gap-2">
                {bucketLabels.map((label) => (
                  <button
                    key={label}
                    type="button"
                    onClick={() => onInputChange({ target: { name: 'age_range', value: label } })}
                    className="px-2.5 py-1 text-xs rounded-full border border-gray-300 text-gray-600 hover:bg-emerald-50 hover:border-emerald-400 hover:text-emerald-700"
                  >
                    {label}
                  </button>
                ))}
              </div>
            )}
          </div>
        </>
      )}
    />
  );
};

export default ToyForm;
