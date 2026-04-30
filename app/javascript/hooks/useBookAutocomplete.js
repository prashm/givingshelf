import { useState, useCallback, useRef, useEffect } from 'react';
import { searchGoogleBooks } from '../lib/googleBooksApi';

export const useBookAutocomplete = () => {
  const [suggestions, setSuggestions] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selectedBook, setSelectedBook] = useState(null);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const abortControllerRef = useRef(null);
  const debounceTimeoutRef = useRef(null);

  // Debounced search function
  const searchBooks = useCallback(async (query, delay = 300) => {
    if (!query || query.length < 2) {
      setSuggestions([]);
      setShowSuggestions(false);
      return;
    }

    if (debounceTimeoutRef.current) {
      clearTimeout(debounceTimeoutRef.current);
      debounceTimeoutRef.current = null;
    }

    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }

    abortControllerRef.current = new AbortController();

    debounceTimeoutRef.current = setTimeout(async () => {
      debounceTimeoutRef.current = null;
      try {
        setLoading(true);
        const items = await searchGoogleBooks(query, { signal: abortControllerRef.current.signal });
        if (items.length > 0) {
          setSuggestions(items);
          setShowSuggestions(true);
        } else {
          setSuggestions([]);
          setShowSuggestions(false);
        }
      } catch (error) {
        if (error.name !== 'AbortError') {
          console.error('Error searching books:', error);
          setSuggestions([]);
          setShowSuggestions(false);
        }
      } finally {
        setLoading(false);
      }
    }, delay);
  }, []);

  const selectBook = useCallback((book) => {
    setSelectedBook(book);
    setShowSuggestions(false);
    setSuggestions([]);
  }, []);

  const clearSelection = useCallback(() => {
    setSelectedBook(null);
    setSuggestions([]);
    setShowSuggestions(false);
  }, []);

  const hideSuggestions = useCallback(() => {
    setShowSuggestions(false);
    setSuggestions([]);
  }, []);

  useEffect(() => {
    return () => {
      if (debounceTimeoutRef.current) {
        clearTimeout(debounceTimeoutRef.current);
      }
      if (abortControllerRef.current) {
        abortControllerRef.current.abort();
      }
    };
  }, []);

  return {
    suggestions,
    loading,
    selectedBook,
    showSuggestions,
    searchBooks,
    selectBook,
    clearSelection,
    hideSuggestions,
  };
};
