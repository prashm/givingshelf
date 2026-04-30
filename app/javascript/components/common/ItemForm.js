import React from 'react';
import MultiImageUpload from './MultiImageUpload';
import ItemFulfillmentFields from './ItemFulfillmentFields';

const ItemForm = ({
  formData,
  validationErrors,
  onInputChange,
  updateFormData,
  communityGroups = [],
  maxImages = 4,
  existingUserImages = [],
  onCropUserImage,
  onCropExistingImage,
  onRemoveExistingImage,
  renderBeforeTitle,
  renderTitleInput,
  renderTypeSpecificFields,
  renderAfterCondition,
  summaryLabel = 'Summary',
  summaryPlaceholder = 'Provide a brief description (10-1000 characters)',
  conditionLabel = 'Condition',
  shareLabel = 'Share this item in',
  shareHelpText = 'This item will only be shared in the groups you select.',
  pickupAddressPlaceholder = 'Enter the address for pickup',
  excludePickupMethods = [],
  isToy = false,
}) => {
  return (
    <>
      {renderBeforeTitle && renderBeforeTitle()}

      {/* Title */}
      <div>
        <label htmlFor="title" className="block text-sm font-medium text-gray-700 mb-2">
          Title *
        </label>
        {renderTitleInput ? (
          renderTitleInput()
        ) : (
          <input
            type="text"
            id="title"
            name="title"
            value={formData.title || ''}
            onChange={onInputChange}
            className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${validationErrors.title ? 'border-red-300' : 'border-gray-300'}`}
            placeholder="Enter title"
          />
        )}
        {validationErrors.title && (
          <p className="mt-1 text-sm font-semibold text-red-600 bg-red-50 px-2 py-1 rounded">{validationErrors.title}</p>
        )}
      </div>

      {renderTypeSpecificFields && renderTypeSpecificFields()}

      {renderAfterCondition && renderAfterCondition()}

      {/* Summary */}
      <div className="mt-4 mb-2">
        <label htmlFor="summary" className="block text-sm font-medium text-gray-700 mb-2">
          {summaryLabel} *
        </label>
        <textarea
          id="summary"
          name="summary"
          value={formData.summary || ''}
          onChange={onInputChange}
          rows={4}
          className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${validationErrors.summary ? 'border-red-300' : 'border-gray-300'}`}
          placeholder={summaryPlaceholder}
        />
        <div className="flex justify-between items-center mt-1">
          {validationErrors.summary && (
            <p className="mt-1 text-sm font-semibold text-red-600 bg-red-50 px-2 py-1 rounded">{validationErrors.summary}</p>
          )}
          <span className={`text-sm ml-auto ${(formData.summary || '').length > 1000 ? 'text-red-600' : 'text-gray-500'}`}>
            {(formData.summary || '').length}/1000
          </span>
        </div>
      </div>

      {/* User Images Upload (Multiple) */}
      <div className="mt-4 mb-6">
        <MultiImageUpload
          images={formData.user_images || []}
          existingImages={existingUserImages || []}
          onImagesChange={(newImages) => {
            if (updateFormData) {
              updateFormData({ user_images: newImages });
            } else {
              onInputChange({
                target: {
                  name: 'user_images',
                  value: null,
                  files: newImages
                }
              });
            }
          }}
          onRemoveImage={(index) => {
            const newImages = [...(formData.user_images || [])];
            newImages.splice(index, 1);
            if (updateFormData) {
              updateFormData({ user_images: newImages });
            } else {
              onInputChange({
                target: {
                  name: 'user_images',
                  value: null,
                  files: newImages
                }
              });
            }
          }}
          onCropImage={onCropUserImage}
          onCropExisting={onCropExistingImage}
          onRemoveExisting={onRemoveExistingImage}
          maxImages={maxImages}
        />
        {validationErrors.user_images && (
          <p className="mt-2 text-sm font-semibold text-red-600 bg-red-50 px-2 py-1 rounded">
            {validationErrors.user_images}
          </p>
        )}
      </div>

      <ItemFulfillmentFields
        formData={formData}
        validationErrors={validationErrors}
        onInputChange={onInputChange}
        communityGroups={communityGroups}
        updateFormData={updateFormData}
        conditionLabel={conditionLabel}
        shareLabel={shareLabel}
        shareHelpText={shareHelpText}
        pickupAddressPlaceholder={pickupAddressPlaceholder}
        excludePickupMethods={excludePickupMethods}
        isToy={isToy}
      />
    </>
  );
};

export default ItemForm;
