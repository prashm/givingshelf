import React from 'react';
import BookTitleAutocomplete from './BookTitleAutocomplete';
import ItemForm from './ItemForm';

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
  openSuggestionsOnLoad = false,
}) => {
  return (
    <ItemForm
      formData={formData}
      validationErrors={validationErrors}
      onInputChange={onInputChange}
      updateFormData={updateFormData}
      communityGroups={communityGroups}
      maxImages={4}
      existingUserImages={existingUserImages}
      onCropUserImage={onCropUserImage}
      onCropExistingImage={onCropExistingImage}
      onRemoveExistingImage={onRemoveExistingImage}
      summaryLabel="Summary"
      summaryPlaceholder="Provide a brief description of the book (10-1000 characters)"
      conditionLabel="Book Condition"
      shareLabel="Share this book in"
      shareHelpText="This book will only be shared in the groups you select."
      pickupAddressPlaceholder="Enter the address for book pickup"
      renderBeforeTitle={() => (
        formData.cover_image && (
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
        )
      )}
      renderTitleInput={() => (
        <BookTitleAutocomplete
          value={formData.title}
          onChange={(value) => onInputChange({ target: { name: 'title', value } })}
          onBookSelect={onBookSelect}
          placeholder="Start typing a book title to search..."
          openSuggestionsOnLoad={openSuggestionsOnLoad}
        />
      )}
      renderTypeSpecificFields={() => (
        <>
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
              className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${validationErrors.author ? 'border-red-300' : 'border-gray-300'}`}
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
              className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${validationErrors.genre ? 'border-red-300' : 'border-gray-300'}`}
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
              className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${validationErrors.published_year ? 'border-red-300' : 'border-gray-300'}`}
              style={{ appearance: 'auto' }}
            >
              {yearOptions && yearOptions.map(year => (
                <option key={year} value={year}>{year}</option>
              ))}
            </select>
            {validationErrors.published_year && (
              <p className="mt-1 text-sm font-semibold text-red-600 bg-red-50 px-2 py-1 rounded">{validationErrors.published_year}</p>
            )}
          </div>
        </>
      )}
      renderAfterCondition={() => (
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
            className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${validationErrors.isbn ? 'border-red-300' : 'border-gray-300'}`}
            placeholder="10 or 13 digit ISBN"
          />
          {validationErrors.isbn && (
            <p className="mt-1 text-sm font-semibold text-red-600 bg-red-50 px-2 py-1 rounded">{validationErrors.isbn}</p>
          )}
        </div>
      )}
    />
  );
};

export default BookForm;
