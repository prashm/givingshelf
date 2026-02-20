import { useState, useCallback, useRef, useEffect } from 'react';

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

    // Clear previous debounce timer so only the last keystroke triggers a request
    if (debounceTimeoutRef.current) {
      clearTimeout(debounceTimeoutRef.current);
      debounceTimeoutRef.current = null;
    }

    // Cancel previous in-flight request
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }

    abortControllerRef.current = new AbortController();

    debounceTimeoutRef.current = setTimeout(async () => {
      debounceTimeoutRef.current = null;
      try {
        setLoading(true);

        const apiKey = document.querySelector('meta[name="google-books-api-key"]')?.getAttribute('content');
        const url = new URL('https://www.googleapis.com/books/v1/volumes');
        url.searchParams.set('q', query);
        url.searchParams.set('maxResults', '8');
        if (apiKey) url.searchParams.set('key', apiKey);

        const response = await fetch(
          url.toString(),
          {
            signal: abortControllerRef.current.signal,
          }
        );

        if (!response.ok) {
          throw new Error('Failed to fetch books');
        }

        const data = await response.json();
        
        if (data.items && data.items.length > 0) {
          const bookSuggestions = data.items.map(item => ({
            id: item.id,
            title: item.volumeInfo?.title || 'Unknown Title',
            authors: item.volumeInfo?.authors || ['Unknown Author'],
            publisher: item.volumeInfo?.publisher || 'Unknown Publisher',
            publishedDate: item.volumeInfo?.publishedDate || '',
            description: item.volumeInfo?.description || '',
            isbn: item.volumeInfo?.industryIdentifiers?.find(id => id.type === 'ISBN_13')?.identifier ||
                  item.volumeInfo?.industryIdentifiers?.find(id => id.type === 'ISBN_10')?.identifier ||
                  '',
            thumbnail: item.volumeInfo?.imageLinks?.thumbnail || 
                      item.volumeInfo?.imageLinks?.smallThumbnail || 
                      '',
            categories: item.volumeInfo?.categories || [],
            pageCount: item.volumeInfo?.pageCount || 0,
            language: item.volumeInfo?.language || 'en',
            fullData: item.volumeInfo
          }));
          
          setSuggestions(bookSuggestions);
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

  // Select a book from suggestions
  const selectBook = useCallback((book) => {
    setSelectedBook(book);
    setShowSuggestions(false);
    setSuggestions([]);
  }, []);

  // Clear selection
  const clearSelection = useCallback(() => {
    setSelectedBook(null);
    setSuggestions([]);
    setShowSuggestions(false);
  }, []);

  // Hide suggestions
  const hideSuggestions = useCallback(() => {
    setShowSuggestions(false);
    setSuggestions([]);
  }, []);

  // Cleanup on unmount
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

