import React, { useState, useRef, useEffect } from 'react';
import { MagnifyingGlassIcon } from '@heroicons/react/24/outline';
import { useBookAutocomplete } from '../../hooks/useBookAutocomplete';
import {
  GoogleBookSuggestionRow,
  GoogleBookSuggestionDropdown,
  GoogleBookNoResultsDropdown,
} from './GoogleBookSuggestions';

const BookTitleAutocomplete = ({ 
  value, 
  onChange, 
  onBookSelect, 
  placeholder = "Start typing a book title...",
  disabled = false,
  openSuggestionsOnLoad = false,
}) => {
  const [inputValue, setInputValue] = useState(value || '');
  const [dropdownPosition, setDropdownPosition] = useState({ top: 0, left: 0, width: 0 });
  const inputRef = useRef(null);
  const containerRef = useRef(null);
  const justSelectedRef = useRef(false);
  const isInitialMountRef = useRef(true);
  const userHasInteractedRef = useRef(false);
  
  const {
    suggestions,
    loading,
    showSuggestions,
    searchBooks,
    selectBook,
    hideSuggestions,
  } = useBookAutocomplete();

  // Update input value when external value changes and trigger search if needed
  useEffect(() => {
    const newValue = value || '';
    
    // On initial mount: either open suggestions (e.g. "Donate a Similar Book") or just set value
    if (isInitialMountRef.current) {
      setInputValue(newValue);
      isInitialMountRef.current = false;
      if (openSuggestionsOnLoad && newValue.length >= 2) {
        userHasInteractedRef.current = true;
        searchBooks(newValue);
      } else {
        hideSuggestions();
      }
      return;
    }
    
    // If a book was just selected, don't trigger search
    if (justSelectedRef.current) {
      setInputValue(newValue);
      justSelectedRef.current = false;
      hideSuggestions();
      return;
    }
    
    // Only trigger search if user has interacted (typed something)
    // This prevents auto-searching when value is set programmatically
    if (userHasInteractedRef.current && newValue.length >= 2) {
      setInputValue(newValue);
      searchBooks(newValue);
    } else {
      setInputValue(newValue);
      hideSuggestions();
    }
  }, [value, searchBooks, hideSuggestions, openSuggestionsOnLoad]);

  // Handle input change
  const handleInputChange = (e) => {
    const newValue = e.target.value;
    setInputValue(newValue);
    userHasInteractedRef.current = true;
    onChange(newValue);
    
    if (newValue.length >= 2) {
      searchBooks(newValue);
    } else {
      hideSuggestions();
    }
  };

  // Handle book selection
  const handleBookSelect = (book) => {
    setInputValue(book.title);
    selectBook(book);
    justSelectedRef.current = true; // Mark that we just selected a book
    onChange(book.title);
    onBookSelect(book);
    hideSuggestions();
  };

  // Handle keyboard navigation
  const handleKeyDown = (e) => {
    if (!showSuggestions || suggestions.length === 0) return;

    const currentIndex = suggestions.findIndex(book => book.title === inputValue);
    
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        const nextIndex = currentIndex < suggestions.length - 1 ? currentIndex + 1 : 0;
        setInputValue(suggestions[nextIndex].title);
        break;
      case 'ArrowUp':
        e.preventDefault();
        const prevIndex = currentIndex > 0 ? currentIndex - 1 : suggestions.length - 1;
        setInputValue(suggestions[prevIndex].title);
        break;
      case 'Enter':
        e.preventDefault();
        if (suggestions.length > 0) {
          handleBookSelect(suggestions[currentIndex >= 0 ? currentIndex : 0]);
        }
        break;
      case 'Escape':
        hideSuggestions();
        break;
    }
  };

  // Calculate dropdown position when suggestions are shown
  useEffect(() => {
    if (showSuggestions && inputRef.current) {
      const rect = inputRef.current.getBoundingClientRect();
      setDropdownPosition({
        top: rect.bottom + window.scrollY + 4, // 4px margin (mt-1)
        left: rect.left + window.scrollX,
        width: rect.width
      });
    }
  }, [showSuggestions, suggestions]);

  // Handle click outside to close suggestions
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (containerRef.current && !containerRef.current.contains(event.target)) {
        hideSuggestions();
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [hideSuggestions]);

  return (
    <div className="relative" ref={containerRef} style={{ zIndex: 1 }}>
      <div className="relative">
        <input
          ref={inputRef}
          type="text"
          value={inputValue}
          onChange={handleInputChange}
          onKeyDown={handleKeyDown}
          onFocus={() => {
            // Only show suggestions on focus if user has typed something
            if (userHasInteractedRef.current && inputValue.length >= 2) {
              searchBooks(inputValue);
            }
          }}
          placeholder={placeholder}
          disabled={disabled}
          className="w-full px-4 py-2 pr-10 border border-gray-300 rounded-md shadow-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 disabled:bg-gray-100 disabled:cursor-not-allowed"
        />
        {!loading && (
          <div className="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
            <MagnifyingGlassIcon className="h-5 w-5 text-gray-400" />
          </div>
        )}
        {loading && (
          <div className="absolute inset-y-0 right-0 pr-3 flex items-center">
            <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600"></div>
          </div>
        )}
      </div>

      {/* Suggestions Dropdown */}
      {showSuggestions && suggestions.length > 0 && inputValue.length >= 2 && (
        <GoogleBookSuggestionDropdown
          style={{
            top: `${dropdownPosition.top}px`,
            left: `${dropdownPosition.left}px`,
            width: `${dropdownPosition.width}px`,
          }}
        >
          {suggestions.map((book) => (
            <GoogleBookSuggestionRow
              key={book.id}
              book={book}
              onSelect={handleBookSelect}
              isHighlighted={inputValue === book.title}
            />
          ))}
        </GoogleBookSuggestionDropdown>
      )}

      {showSuggestions && suggestions.length === 0 && inputValue.length >= 2 && !loading && (
        <GoogleBookNoResultsDropdown
          style={{
            top: `${dropdownPosition.top}px`,
            left: `${dropdownPosition.left}px`,
            width: `${dropdownPosition.width}px`,
          }}
          searchText={inputValue}
        />
      )}
    </div>
  );
};

export default BookTitleAutocomplete;

