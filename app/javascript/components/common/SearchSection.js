import React from 'react';

const SearchSection = ({
  queryLabel = 'Book Title or Author',
  queryPlaceholder = 'Search by title or author...',
  queryValue = '',
  onQueryChange,
  onSearch,
  submitOnEnter = true,
  searchButtonText = 'Search',
  searchDisabled = false,
  secondaryField = null,
  secondaryFieldWidthClassName = 'md:w-1/4',
  searchButtonWidthClassName = 'md:w-1/6'
}) => {
  return (
    <div className="flex flex-col md:flex-row gap-4 mb-6">
      <div className="flex-grow">
        <label className="block text-gray-700 mb-2">
          {queryLabel}
        </label>
        <div className="relative">
          <input
            className="w-full border border-gray-200 rounded-md p-3 pr-10"
            placeholder={queryPlaceholder}
            type="text"
            value={queryValue}
            onChange={(e) => onQueryChange?.(e.target.value)}
            onKeyDown={(e) => {
              if (e.key !== 'Enter') return;
              if (!submitOnEnter) {
                e.preventDefault();
                return;
              }
              onSearch?.();
            }}
          />
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="20"
            height="20"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            className="lucide lucide-search absolute right-3 top-3 text-gray-400"
          >
            <circle cx="11" cy="11" r="8"></circle>
            <path d="m21 21-4.3-4.3"></path>
          </svg>
        </div>
      </div>

      {secondaryField && (
        <div className={`${secondaryFieldWidthClassName} relative`}>
          {secondaryField}
        </div>
      )}

      <div className={`${searchButtonWidthClassName} flex items-end`}>
        <button
          type="button"
          className={`w-full py-3 px-4 rounded-md transition-colors ${searchDisabled
            ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
            : 'bg-emerald-600 text-white hover:bg-emerald-700 cursor-pointer'
            }`}
          onClick={() => onSearch?.()}
          disabled={searchDisabled}
        >
          {searchButtonText}
        </button>
      </div>
    </div>
  );
};

export default SearchSection;

