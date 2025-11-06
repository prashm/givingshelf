import React from 'react';
import BookTitleAutocomplete from './BookTitleAutocomplete';

const BookForm = ({
  formData,
  validationErrors,
  onInputChange,
  onBookSelect,
  currentYear,
  yearOptions,
  isEditMode = false,
  imageUploadSection = null,
}) => {
  return (
    <>
      {/* API Cover Image Display */}
      {formData.api_cover_image && (
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Cover Image from Search
          </label>
          <div className="flex justify-center">
            <img 
              src={formData.api_cover_image.replace('http:', 'https:')} 
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
          className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${
            validationErrors.author ? 'border-red-300' : 'border-gray-300'
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
          Genre *
        </label>
        <input
          type="text"
          id="genre"
          name="genre"
          value={formData.genre}
          onChange={onInputChange}
          className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${
            validationErrors.genre ? 'border-red-300' : 'border-gray-300'
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
          className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${
            validationErrors.published_year ? 'border-red-300' : 'border-gray-300'
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

      {/* Image Upload Section */}
      {imageUploadSection}

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
          className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${
            validationErrors.isbn ? 'border-red-300' : 'border-gray-300'
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
          className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${
            validationErrors.summary ? 'border-red-300' : 'border-gray-300'
          }`}
          placeholder="Provide a brief description of the book (10-1000 characters)"
        />
        <div className="flex justify-between items-center mt-1">
          {validationErrors.summary && (
            <p className="mt-1 text-sm font-semibold text-red-600 bg-red-50 px-2 py-1 rounded">{validationErrors.summary}</p>
          )}
          <span className={`text-sm ml-auto ${
            formData.summary.length > 1000 ? 'text-red-600' : 'text-gray-500'
          }`}>
            {formData.summary.length}/1000
          </span>
        </div>
      </div>
    </>
  );
};

export default BookForm;

