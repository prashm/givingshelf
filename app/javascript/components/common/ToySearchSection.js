import React from 'react';
import AgeRangeSelect from './AgeRangeSelect';

const ToySearchSection = ({
  queryLabel = 'Toy Title or Brand',
  queryPlaceholder = 'Search by title or brand...',
  queryValue = '',
  onQueryChange,
  onSearch,
  submitOnEnter = true,
  searchButtonText = 'Search',
  searchDisabled = false,
  searchLoading = false,
  secondaryField = null,
  secondaryFieldWidthClassName = 'md:w-1/4',
  searchButtonWidthClassName = 'md:w-1/6',
  ageRangeValue = '',
  onAgeRangeChange,
  ageRangeOptions = [],
  ageRangeOptionsLoading = false,
}) => {
  const buttonDisabled = searchDisabled || searchLoading;
  const buttonLabel = searchLoading ? 'Searching...' : searchButtonText;
  const hasInput = (queryValue || '').trim().length > 0;

  return (
    <div className="flex flex-col md:flex-row gap-4 mb-6">
      <div className="flex-grow min-w-0">
        <label className="block text-gray-700 mb-2">
          {queryLabel}
        </label>
        <div className="relative">
          <input
            className={`w-full border border-gray-200 rounded-md p-3 ${hasInput ? 'pr-14' : 'pr-10'}`}
            placeholder={queryPlaceholder}
            type="text"
            value={queryValue}
            onChange={(e) => onQueryChange?.(e.target.value)}
            onKeyDown={(e) => {
              if (e.key !== 'Enter') return;
              if (!submitOnEnter || buttonDisabled) {
                e.preventDefault();
                return;
              }
              onSearch?.();
            }}
          />
          {hasInput ? (
            <button
              type="button"
              onClick={() => onQueryChange?.('')}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-emerald-600 hover:text-emerald-700 hover:underline focus:outline-none focus:underline"
            >
              Clear
            </button>
          ) : (
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
              className="lucide lucide-search absolute right-3 top-1/2 -translate-y-1/2 text-gray-400"
            >
              <circle cx="11" cy="11" r="8"></circle>
              <path d="m21 21-4.3-4.3"></path>
            </svg>
          )}
        </div>
      </div>

      <div className="md:w-40 relative">
        <label className="block text-gray-700 mb-2">Age Range</label>
        <AgeRangeSelect
          options={ageRangeOptions}
          loading={ageRangeOptionsLoading}
          value={ageRangeValue}
          onChange={onAgeRangeChange}
          includeAllOption
          className="w-full border border-gray-200 rounded-md p-3 bg-white"
        />
      </div>

      {secondaryField && (
        <div className={`${secondaryFieldWidthClassName} relative`}>
          {secondaryField}
        </div>
      )}

      <div className={`${searchButtonWidthClassName} flex items-end`}>
        <button
          type="button"
          className={`w-full py-3 px-4 rounded-md transition-colors ${buttonDisabled
            ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
            : 'bg-emerald-600 text-white hover:bg-emerald-700 cursor-pointer'
            }`}
          onClick={() => onSearch?.()}
          disabled={buttonDisabled}
        >
          {buttonLabel}
        </button>
      </div>
    </div>
  );
};

export default ToySearchSection;
