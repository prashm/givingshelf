import { useState, useCallback, useRef, useEffect } from 'react';
import { searchGoogleBooks } from '../lib/googleBooksApi';

const MIN_QUERY_LENGTH = 4;
const DEFAULT_DEBOUNCE_MS = 600;

/**
 * Detects an ISBN-10 or ISBN-13 in free-text search input.
 * Strips spaces and dashes; accepts a trailing X check digit on ISBN-10.
 * Returns the compact form, or null if the query is not an ISBN.
 */
function isbnFromQuery(query) {
  const compact = String(query || '').replace(/[\s-]/g, '').toUpperCase();
  return /^(\d{13}|\d{9}[\dX])$/.test(compact) ? compact : null;
}

export const useBookAutocomplete = () => {
  const [suggestions, setSuggestions] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selectedBook, setSelectedBook] = useState(null);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const abortControllerRef = useRef(null);
  const debounceTimeoutRef = useRef(null);

  // Debounced search. Detects ISBN from the query (or an explicit isbn arg)
  // and passes it through so searchGoogleBooks uses q=isbn:VALUE.
  // ISBN queries fire immediately (delay 0).
  const searchBooks = useCallback(async (query, delay = DEFAULT_DEBOUNCE_MS, isbn = null) => {
    const trimmed = (query || '').trim();
    const resolvedIsbn = isbnFromQuery(isbn) || isbnFromQuery(trimmed);
    if (!resolvedIsbn && trimmed.length < MIN_QUERY_LENGTH) {
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

    const effectiveDelay = resolvedIsbn ? 0 : delay;

    debounceTimeoutRef.current = setTimeout(async () => {
      debounceTimeoutRef.current = null;
      try {
        setLoading(true);
        const items = await searchGoogleBooks(trimmed, {
          signal: abortControllerRef.current.signal,
          ...(resolvedIsbn ? { isbn: resolvedIsbn } : {})
        });
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
    }, effectiveDelay);
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
