import React from 'react';
import BookTitleAutocomplete from './BookTitleAutocomplete';
import MultiImageUpload from './MultiImageUpload';
import * as Constants from '../../lib/constants';

const BookForm = ({
  formData,
  validationErrors,
  onInputChange,
  onBookSelect,
  currentYear,
  yearOptions,
  isEditMode = false,
  imageUploadSection = null,
  existingUserImages = [],
  communityGroups = [],
  updateFormData,
  onCropUserImage,
  onCropExistingImage,
  onRemoveExistingImage,
}) => {
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
    if (!updateFormData) return;
    const id = parseInt(groupId, 10);
    if (!Number.isFinite(id)) return;

    const has = selectedGroupIds.includes(id);
    const next = has ? selectedGroupIds.filter((x) => x !== id) : [...selectedGroupIds, id];
    updateFormData({ community_group_ids: next });
  };

  return (
    <>
      {/* API Cover Image Display */}
      {formData.cover_image && (
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Cover Image from Search
          </label>
          <div className="flex justify-center">
            <img
              src={formData.cover_image.replace('http:', 'https:')}
              alt="Book cover from search"
              className="w-16 h-20 sm:w-18 sm:h-24 md:w-20 md:h-28 object-cover rounded border shadow-sm"
              onError={(e) => {
                e.target.style.display = 'none';
              }}
            />
          </div>
          <p className="text-xs text-gray-500 text-center mt-2">
            Cover image found from book search. You can still upload your own image below.
          </p>
        </div>
      )}

      {/* Title */}
      <div>
        <label htmlFor="title" className="block text-sm font-medium text-gray-700 mb-2">
          Title *
        </label>
        <BookTitleAutocomplete
          value={formData.title}
          onChange={(value) => onInputChange({ target: { name: 'title', value } })}
          onBookSelect={onBookSelect}
          placeholder="Start typing a book title to search..."
        />
        {validationErrors.title && (
          <p className="mt-1 text-sm font-semibold text-red-600 bg-red-50 px-2 py-1 rounded">{validationErrors.title}</p>
        )}
      </div>

      {/* Author */}
      <div>
        <label htmlFor="author" className="block text-sm font-medium text-gray-700 mb-2">
          Author *
        </label>
        <input
          type="text"
          id="author"
          name="author"
          value={formData.author}
          onChange={onInputChange}
          className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${validationErrors.author ? 'border-red-300' : 'border-gray-300'
            }`}
          placeholder="Enter author name"
        />
        {validationErrors.author && (
          <p className="mt-1 text-sm font-semibold text-red-600 bg-red-50 px-2 py-1 rounded">{validationErrors.author}</p>
        )}
      </div>

      {/* Genre */}
      <div>
        <label htmlFor="genre" className="block text-sm font-medium text-gray-700 mb-2">
          Genre
        </label>
        <input
          type="text"
          id="genre"
          name="genre"
          value={formData.genre}
          onChange={onInputChange}
          className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${validationErrors.genre ? 'border-red-300' : 'border-gray-300'
            }`}
          placeholder="e.g., Fiction, Science Fiction, Mystery, etc."
        />
        {validationErrors.genre && (
          <p className="mt-1 text-sm font-semibold text-red-600 bg-red-50 px-2 py-1 rounded">{validationErrors.genre}</p>
        )}
      </div>

      {/* Published Year */}
      <div>
        <label htmlFor="published_year" className="block text-sm font-medium text-gray-700 mb-2">
          Published Year *
        </label>
        <select
          id="published_year"
          name="published_year"
          value={formData.published_year}
          onChange={onInputChange}
          className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${validationErrors.published_year ? 'border-red-300' : 'border-gray-300'
            }`}
        >
          {yearOptions.map(year => (
            <option key={year} value={year}>{year}</option>
          ))}
        </select>
        {validationErrors.published_year && (
          <p className="mt-1 text-sm font-semibold text-red-600 bg-red-50 px-2 py-1 rounded">{validationErrors.published_year}</p>
        )}
      </div>

      {/* Group availability */}
      {sortedGroups.length > 0 && updateFormData && (
        <div className="mt-2 mb-2">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Share this book in
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
            This book will only be shared in the groups you select.
          </p>
        </div>
      )}


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
          maxImages={4}
        />
        {validationErrors.user_images && (
          <p className="mt-2 text-sm font-semibold text-red-600 bg-red-50 px-2 py-1 rounded">
            {validationErrors.user_images}
          </p>
        )}
      </div>

      {/* Condition */}
      <div>
        <label htmlFor="condition" className="block text-sm font-medium text-gray-700 mb-2">
          Book Condition *
        </label>
        <select
          id="condition"
          name="condition"
          value={formData.condition}
          onChange={onInputChange}
          className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
        >
          <option value="excellent">Excellent - Like new, minimal wear</option>
          <option value="good">Good - Light wear, still in good shape</option>
          <option value="fair">Fair - Moderate wear, readable condition</option>
          <option value="poor">Poor - Heavy wear, may have damage</option>
        </select>
      </div>

      {/* ISBN */}
      <div>
        <label htmlFor="isbn" className="block text-sm font-medium text-gray-700 mb-2">
          ISBN (Optional)
        </label>
        <input
          type="text"
          id="isbn"
          name="isbn"
          value={formData.isbn}
          onChange={onInputChange}
          className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${validationErrors.isbn ? 'border-red-300' : 'border-gray-300'
            }`}
          placeholder="10 or 13 digit ISBN"
        />
        {validationErrors.isbn && (
          <p className="mt-1 text-sm font-semibold text-red-600 bg-red-50 px-2 py-1 rounded">{validationErrors.isbn}</p>
        )}
      </div>

      {/* Summary */}
      <div>
        <label htmlFor="summary" className="block text-sm font-medium text-gray-700 mb-2">
          Summary *
        </label>
        <textarea
          id="summary"
          name="summary"
          value={formData.summary}
          onChange={onInputChange}
          rows={4}
          className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${validationErrors.summary ? 'border-red-300' : 'border-gray-300'
            }`}
          placeholder="Provide a brief description of the book (10-1000 characters)"
        />
        <div className="flex justify-between items-center mt-1">
          {validationErrors.summary && (
            <p className="mt-1 text-sm font-semibold text-red-600 bg-red-50 px-2 py-1 rounded">{validationErrors.summary}</p>
          )}
          <span className={`text-sm ml-auto ${formData.summary.length > 1000 ? 'text-red-600' : 'text-gray-500'
            }`}>
            {formData.summary.length}/1000
          </span>
        </div>
      </div>

      {/* Personal Note */}
      <div>
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
          placeholder="write a note or short story about what this book meant to you..."
        />
      </div>

      {/* Pickup Method */}
      <div>
        <label htmlFor="pickup_method" className="block text-sm font-medium text-gray-700 mb-2">
          Pickup Method
        </label>
        <select
          id="pickup_method"
          name="pickup_method"
          value={formData.pickup_method || ''}
          onChange={(e) => {
            onInputChange(e);
            // Clear pickup address if "meet in person" is selected
            if (e.target.value === 'meet_in_person') {
              if (updateFormData) {
                updateFormData({ pickup_address: '' });
              } else {
                onInputChange({ target: { name: 'pickup_address', value: '' } });
              }
            }
          }}
          className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
        >
          <option value="">Select pickup method...</option>
          <option value="meet_in_person">Meet in person</option>
          <option value="pickup_little_library_drop">Pickup little library drop</option>
          <option value="pickup_porch_drop">Pickup porch drop</option>
        </select>
      </div>

      {/* Pickup Address - Conditional (not shown for "meet in person") */}
      {formData.pickup_method && formData.pickup_method !== 'meet_in_person' && (
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
            placeholder="Enter the address for book pickup"
          />
        </div>
      )}
    </>
  );
};

export default BookForm;

