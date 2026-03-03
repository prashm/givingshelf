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
              className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              placeholder="e.g., 3-6 years, 6+"
            />
          </div>
        </>
      )}
    />
  );
};

export default ToyForm;
