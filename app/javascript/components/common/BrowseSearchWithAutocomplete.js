import React, { useState, useRef, useEffect } from 'react';
import { useBookAutocomplete } from '../../hooks/useBookAutocomplete';
import {
  GoogleBookSuggestionRow,
  GoogleBookSuggestionDropdown,
} from './GoogleBookSuggestions';

/**
 * SearchSection layout (label + input + clear + Google Books dropdown + button) for /books browse.
 */
const BrowseSearchWithAutocomplete = ({
  queryLabel = 'Book Title or Author',
  queryPlaceholder = 'Search by title or author...',
  queryValue = '',
  onQueryChange,
  onSearch,
  onSuggestionSelect = null,
  submitOnEnter = true,
  searchButtonText = 'Search',
  searchLoading = false,
  searchDisabled = false,
  secondaryField = null,
  secondaryFieldWidthClassName = 'md:w-1/4',
  searchButtonWidthClassName = 'md:w-1/6'
}) => {
  const [local, setLocal] = useState(queryValue);
  const [dropdownPosition, setDropdownPosition] = useState({ top: 0, left: 0, width: 0 });
  const {
    suggestions,
    loading: suggestionsLoading,
    showSuggestions,
    searchBooks,
    selectBook,
    hideSuggestions
  } = useBookAutocomplete();
  const containerRef = useRef(null);
  const inputRef = useRef(null);

  useEffect(() => {
    setLocal(queryValue);
  }, [queryValue]);

  useEffect(() => {
    const onDoc = (e) => {
      if (containerRef.current && !containerRef.current.contains(e.target)) {
        hideSuggestions();
      }
    };
    document.addEventListener('mousedown', onDoc);
    return () => document.removeEventListener('mousedown', onDoc);
  }, [hideSuggestions]);

  useEffect(() => {
    if (showSuggestions && inputRef.current) {
      const rect = inputRef.current.getBoundingClientRect();
      setDropdownPosition({
        top: rect.bottom + window.scrollY + 4,
        left: rect.left + window.scrollX,
        width: rect.width
      });
    }
  }, [showSuggestions, suggestions]);

  const handleChange = (e) => {
    const v = e.target.value;
    setLocal(v);
    onQueryChange?.(v);
    if (v.length >= 2) {
      searchBooks(v);
    } else {
      hideSuggestions();
    }
  };

  const handlePick = (s) => {
    const title = (s.title || '').trim();
    setLocal(title);
    onQueryChange?.(title);
    selectBook(s);
    onSuggestionSelect?.(s);
    hideSuggestions();
    onSearch?.(title);
  };

  const hasInput = (local || '').trim().length > 0;
  const showRightControl = hasInput || suggestionsLoading;
  const inputRightPadding = showRightControl ? 'pr-20' : 'pr-3';
  const buttonDisabled = searchDisabled || searchLoading;
  const buttonLabel = searchLoading ? 'Searching...' : searchButtonText;

  return (
    <div className="flex flex-col md:flex-row gap-4 mb-6">
      <div className="flex-grow" ref={containerRef}>
        <label className="block text-gray-700 mb-2">{queryLabel}</label>
        <div className="relative">
          <input
            ref={inputRef}
            className={`w-full border border-gray-200 rounded-md p-3 ${inputRightPadding}`}
            placeholder={queryPlaceholder}
            type="text"
            value={local}
            aria-busy={suggestionsLoading}
            onChange={handleChange}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault();
                hideSuggestions();
                if (submitOnEnter && !buttonDisabled) onSearch?.((local || '').trim());
              }
            }}
            autoComplete="off"
          />
          {suggestionsLoading && (
            <div
              className="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none"
              aria-hidden
            >
              <div className="animate-spin rounded-full h-4 w-4 border-2 border-gray-200 border-b-blue-600" />
            </div>
          )}
          {!suggestionsLoading && hasInput && (
            <button
              type="button"
              onClick={() => { setLocal(''); onQueryChange?.(''); hideSuggestions(); }}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-emerald-600 hover:underline"
            >
              Clear
            </button>
          )}
          {showSuggestions && suggestions.length > 0 && (local || '').trim().length >= 2 && (
            <GoogleBookSuggestionDropdown
              style={{
                top: `${dropdownPosition.top}px`,
                left: `${dropdownPosition.left}px`,
                width: `${dropdownPosition.width}px`,
              }}
            >
              {suggestions.map((s) => (
                <GoogleBookSuggestionRow
                  key={s.id}
                  book={s}
                  onSelect={handlePick}
                  onMouseDown={(e) => e.preventDefault()}
                />
              ))}
            </GoogleBookSuggestionDropdown>
          )}
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
          className={`w-full py-3 px-4 rounded-md transition-colors ${
            buttonDisabled ? 'bg-gray-300 text-gray-500 cursor-not-allowed' : 'bg-emerald-600 text-white hover:bg-emerald-700 cursor-pointer'
          }`}
          onClick={() => { hideSuggestions(); onSearch?.((local || '').trim()); }}
          disabled={buttonDisabled}
        >
          {buttonLabel}
        </button>
      </div>
    </div>
  );
};

export default BrowseSearchWithAutocomplete;
