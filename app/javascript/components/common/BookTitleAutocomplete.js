import React, { useState, useRef, useEffect } from 'react';
import { MagnifyingGlassIcon } from '@heroicons/react/24/outline';
import { useBookAutocomplete } from '../../hooks/useBookAutocomplete';

const BookTitleAutocomplete = ({ 
  value, 
  onChange, 
  onBookSelect, 
  placeholder = "Start typing a book title...",
  disabled = false 
}) => {
  const [inputValue, setInputValue] = useState(value || '');
  const inputRef = useRef(null);
  const containerRef = useRef(null);
  
  const {
    suggestions,
    loading,
    showSuggestions,
    searchBooks,
    selectBook,
    hideSuggestions,
  } = useBookAutocomplete();

  // Update input value when external value changes
  useEffect(() => {
    setInputValue(value || '');
  }, [value]);

  // Handle input change
  const handleInputChange = (e) => {
    const newValue = e.target.value;
    setInputValue(newValue);
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
    <div className="relative" ref={containerRef}>
      <div className="relative">
        <input
          ref={inputRef}
          type="text"
          value={inputValue}
          onChange={handleInputChange}
          onKeyDown={handleKeyDown}
          onFocus={() => {
            if (inputValue.length >= 2) {
              searchBooks(inputValue);
            }
          }}
          placeholder={placeholder}
          disabled={disabled}
          className="w-full px-4 py-2 pl-10 border border-gray-300 rounded-md shadow-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 disabled:bg-gray-100 disabled:cursor-not-allowed"
        />
        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
          <MagnifyingGlassIcon className="h-5 w-5 text-gray-400" />
        </div>
        {loading && (
          <div className="absolute inset-y-0 right-0 pr-3 flex items-center">
            <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600"></div>
          </div>
        )}
      </div>

      {/* Suggestions Dropdown */}
      {showSuggestions && suggestions.length > 0 && (
        <div className="absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg max-h-80 overflow-y-auto">
          {suggestions.map((book, index) => (
            <div
              key={book.id}
              onClick={() => handleBookSelect(book)}
              className={`px-4 py-3 cursor-pointer border-b border-gray-100 last:border-b-0 hover:bg-gray-50 ${
                inputValue === book.title ? 'bg-blue-50' : ''
              }`}
            >
              <div className="flex items-start space-x-3">
                {book.thumbnail && (
                  <img
                    src={book.thumbnail.replace('http:', 'https:')}
                    alt={book.title}
                    className="w-12 h-16 object-cover rounded border"
                    onError={(e) => {
                      e.target.style.display = 'none';
                    }}
                  />
                )}
                <div className="flex-1 min-w-0">
                  <h4 className="text-sm font-medium text-gray-900 truncate">
                    {book.title}
                  </h4>
                  <p className="text-sm text-gray-600 truncate">
                    by {book.authors.join(', ')}
                  </p>
                  <div className="flex items-center space-x-2 mt-1">
                    {book.publisher && (
                      <span className="text-xs text-gray-500">
                        {book.publisher}
                      </span>
                    )}
                    {book.publishedDate && (
                      <span className="text-xs text-gray-500">
                        • {new Date(book.publishedDate).getFullYear()}
                      </span>
                    )}
                  </div>
                  {book.isbn && (
                    <span className="text-xs text-gray-400">
                      ISBN: {book.isbn}
                    </span>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* No results message */}
      {showSuggestions && suggestions.length === 0 && inputValue.length >= 2 && !loading && (
        <div className="absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg">
          <div className="px-4 py-3 text-sm text-gray-500">
            No books found for "{inputValue}"
          </div>
        </div>
      )}
    </div>
  );
};

export default BookTitleAutocomplete;

