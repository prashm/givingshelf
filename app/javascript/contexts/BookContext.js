import React, { createContext, useContext, useState, useCallback, useMemo } from 'react';
import axios from '../lib/axios';

const BookContext = createContext();

export const useBooks = () => {
  const context = useContext(BookContext);
  if (!context) {
    throw new Error('useBooks must be used within a BookProvider');
  }
  return context;
};

export const BookProvider = ({ children }) => {
  const [books, setBooks] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [paginationMeta, setPaginationMeta] = useState({
    total: 0,
    hasMore: false,
    nextPageUrl: null
  });
  const [currentEndpoint, setCurrentEndpoint] = useState('/api/books'); // Track which endpoint was used

  // Mobile Chrome can abort uploads with net::ERR_UPLOAD_FILE_CHANGED when the underlying
  // camera/gallery file is "temporary" and gets rewritten/invalidated while uploading.
  // To make uploads stable, we clone files into memory before appending to FormData.
  const toStableFile = useCallback(async (file, fallbackName = 'upload.jpg') => {
    if (!file) return null;

    // If it's already a Blob/File, clone bytes into memory to avoid file-handle invalidation.
    if (file instanceof Blob) {
      const name =
        // Some browsers attach name on File; some code attaches `name` on Blob.
        (file instanceof File && file.name) || file.name || fallbackName;
      const type = file.type || 'application/octet-stream';

      const bytes = await file.arrayBuffer();
      return new File([bytes], name, { type, lastModified: Date.now() });
    }

    // String URL (e.g., API cover image) should be sent as-is.
    if (typeof file === 'string') return file;

    return null;
  }, []);

  // Validate total image size before upload
  const validateImageSize = useCallback((bookData) => {
    const MAX_TOTAL_SIZE = 20 * 1024 * 1024; // 20MB
    let totalSize = 0;
    
    if (bookData.user_images && Array.isArray(bookData.user_images)) {
      for (const img of bookData.user_images) {
        if (img instanceof File || img instanceof Blob) {
          totalSize += img.size;
        }
      }
    }
    
    if (totalSize > MAX_TOTAL_SIZE) {
      const totalMB = (totalSize / (1024 * 1024)).toFixed(1);
      return {
        valid: false,
        error: `Total image size (${totalMB}MB) exceeds 20MB limit. Please reduce image sizes or remove some photos.`
      };
    }
    
    return { valid: true };
  }, []);

  // Build FormData from bookData
  const buildFormData = useCallback(async (bookData, options = {}) => {
    const { includeTextFields = false, textFields = [] } = options;
    const formData = new FormData();

    // For updates, always include text fields first (even if empty)
    if (includeTextFields) {
      textFields.forEach(key => {
        let value = '';
        if (bookData.hasOwnProperty(key)) {
          if (bookData[key] === null || bookData[key] === undefined) {
            value = '';
          } else {
            value = String(bookData[key]);
          }
        }
        formData.append(`book[${key}]`, value);
      });
    }

    // Process all fields
    for (const key of Object.keys(bookData)) {
      // Skip text fields if they were already handled above
      if (includeTextFields && textFields.includes(key)) {
        continue;
      }
      
      if (key === 'user_images' && Array.isArray(bookData[key])) {
        // Append each file separately for multiple attachments (stabilize on mobile)
        for (let i = 0; i < bookData[key].length; i++) {
          const stable = await toStableFile(bookData[key][i], `user-image-${i + 1}.jpg`);
          if (stable instanceof File) {
            formData.append('book[user_images][]', stable);
          }
        }
      } else if (key === 'community_group_ids' && Array.isArray(bookData[key])) {
        bookData[key].forEach((id) => {
          formData.append('book[community_group_ids][]', id);
        });
      } else if (key === 'remove_user_image_indices' && Array.isArray(bookData[key])) {
        // Append removed image indices (only for updates)
        bookData[key].forEach((index) => {
          formData.append(`book[remove_user_image_indices][]`, index);
        });
      } else if (key === 'cover_image') {
        const stable = await toStableFile(bookData[key], 'cover-image.jpg');
        if (stable instanceof File) {
          formData.append('book[cover_image]', stable);
        } else if (typeof stable === 'string') {
          formData.append('book[cover_image]', stable);
        }
      } else if (bookData[key] !== null && bookData[key] !== undefined) {
        formData.append(`book[${key}]`, bookData[key]);
      }
    }

    return formData;
  }, [toStableFile]);

  const fetchBooks = useCallback(async (params = {}, append = false) => {
    setLoading(true);
    setError(null);
    try {
      // Set default size to 6 if not specified
      const paginationParams = {
        'page[size]': 6,
        ...params
      };
      
      const endpoint = '/api/books';
      setCurrentEndpoint(endpoint);
      
      const response = await axios.get(endpoint, {
        params: paginationParams,
        withCredentials: true
      });
      
      // Handle paginated response structure
      if (response.data && response.data.data) {
        // Paginated response: { data: [...], meta: {...}, links: {...} }
        const booksData = response.data.data;
        const meta = response.data.meta || {};
        const links = response.data.links || {};
        
        // Extract total from meta.page.total (nested structure)
        const total = meta.page?.total || meta.total || 0;
        
        if (append) {
          setBooks(prev => [...prev, ...booksData]);
        } else {
          setBooks(booksData);
        }
        
        setPaginationMeta({
          total: total,
          hasMore: !!links.next,
          nextPageUrl: links.next || null
        });
      } else {
        // Fallback for non-paginated response (backward compatibility)
        const booksData = Array.isArray(response.data) ? response.data : [];
        if (append) {
          setBooks(prev => [...prev, ...booksData]);
        } else {
          setBooks(booksData);
        }
        setPaginationMeta({
          total: booksData.length,
          hasMore: false,
          nextPageUrl: null
        });
      }
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to fetch books');
    } finally {
      setLoading(false);
    }
  }, []);
  
  const loadMoreBooks = useCallback(async () => {
    if (!paginationMeta.nextPageUrl || loading) return;
    
    setLoading(true);
    setError(null);
    try {
      let url = paginationMeta.nextPageUrl;
      
      // If nextPageUrl is a relative path, make it absolute
      if (url.startsWith('/')) {
        url = `${window.location.origin}${url}`;
      } else if (!url.startsWith('http://') && !url.startsWith('https://')) {
        // If it's just a path without leading slash, add it
        url = `${window.location.origin}/${url}`;
      }
      
      // Extract query params from URL
      const urlObj = new URL(url);
      const params = {};
      urlObj.searchParams.forEach((value, key) => {
        params[key] = value;
      });
      
      // Use the same endpoint that was used originally (could be /api/books or /api/books/search)
      const endpoint = currentEndpoint;
      
      const response = await axios.get(endpoint, {
        params,
        withCredentials: true
      });
      
      if (response.data && response.data.data) {
        const booksData = response.data.data;
        const meta = response.data.meta || {};
        const links = response.data.links || {};
        
        // Extract total from meta.page.total (nested structure)
        const total = meta.page?.total || meta.total || paginationMeta.total;
        
        setBooks(prev => [...prev, ...booksData]);
        setPaginationMeta({
          total: total,
          hasMore: !!links.next,
          nextPageUrl: links.next || null
        });
      }
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to load more books');
    } finally {
      setLoading(false);
    }
  }, [paginationMeta, loading, currentEndpoint]);

  const searchBooks = useCallback(async (query, zipCode, append = false, radius = null, communityGroupId = null, subGroupId = null) => {
    setLoading(true);
    setError(null);
    try {
      // Set default size to 6 if not specified
      const paginationParams = {
        'page[size]': 6,
        query: query || '',
        zip_code: zipCode
      };
      
      if (radius) {
        paginationParams.radius = radius;
      }
      
      if (communityGroupId) {
        paginationParams.community_group_id = communityGroupId;
      }
      
      if (subGroupId) {
        paginationParams.sub_group_id = subGroupId;
      }
      
      const endpoint = '/api/books/search';
      setCurrentEndpoint(endpoint);
      
      const response = await axios.get(endpoint, {
        params: paginationParams,
        withCredentials: true
      });
      
      // Handle paginated response structure
      if (response.data && response.data.data) {
        // Paginated response: { data: [...], meta: {...}, links: {...} }
        const booksData = response.data.data;
        const meta = response.data.meta || {};
        const links = response.data.links || {};
        
        // Extract total from meta.page.total (nested structure)
        const total = meta.page?.total || meta.total || 0;
        
        if (append) {
          setBooks(prev => [...prev, ...booksData]);
        } else {
          setBooks(booksData);
        }
        
        setPaginationMeta({
          total: total,
          hasMore: !!links.next,
          nextPageUrl: links.next || null
        });
      } else {
        // Fallback for non-paginated response (backward compatibility)
        const booksData = Array.isArray(response.data) ? response.data : [];
        if (append) {
          setBooks(prev => [...prev, ...booksData]);
        } else {
          setBooks(booksData);
        }
        setPaginationMeta({
          total: booksData.length,
          hasMore: false,
          nextPageUrl: null
        });
      }
    } catch (err) {
      setError(err.response?.data?.error || 'Search failed');
    } finally {
      setLoading(false);
    }
  }, []);

  const getBook = useCallback(async (id) => {
    setLoading(true);
    setError(null);
    try {
      const response = await axios.get(`/api/books/${id}`, {
        withCredentials: true
      });
      return response.data;
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to fetch book');
      return null;
    } finally {
      setLoading(false);
    }
  }, []);

  const createBook = useCallback(async (bookData) => {
    setLoading(true);
    setError(null);
    try {
      // Validate total image size
      const validation = validateImageSize(bookData);
      if (!validation.valid) {
        setError(validation.error);
        setLoading(false);
        return { success: false, error: validation.error };
      }
      
      // Build FormData
      const formData = await buildFormData(bookData);

      // Submit request
      const response = await axios.post('/api/books', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
        withCredentials: true
      });

      // Update state
      setBooks(prev => [response.data, ...prev]);
      return { success: true, book: response.data };
    } catch (err) {
      const errorMsg = err.response?.data?.errors?.join(', ') || 'Failed to create book';
      setError(errorMsg);
      return { success: false, error: errorMsg };
    } finally {
      setLoading(false);
    }
  }, [validateImageSize, buildFormData]);

  const updateBook = useCallback(async (bookId, bookData) => {
    setLoading(true);
    setError(null);
    try {
      // Validate total image size
      const validation = validateImageSize(bookData);
      if (!validation.valid) {
        setError(validation.error);
        setLoading(false);
        return { success: false, error: validation.error };
      }
      
      // Build FormData with update-specific options
      const textFields = ['personal_note', 'pickup_method', 'pickup_address'];
      const formData = await buildFormData(bookData, {
        includeTextFields: true,
        textFields: textFields
      });

      // Submit request
      const response = await axios.patch(`/api/books/${bookId}`, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
        withCredentials: true
      });

      // Update state
      setBooks(prev => prev.map(book =>
        book.id === bookId ? response.data : book
      ));
      return { success: true, book: response.data };
    } catch (err) {
      console.error('Error updating book:', err);
      const errorMsg = err.response?.data?.errors?.join(', ') || 'Failed to update book';
      setError(errorMsg);
      return { success: false, error: errorMsg };
    } finally {
      setLoading(false);
    }
  }, [validateImageSize, buildFormData]);

  const deleteBook = useCallback(async (bookId) => {
    setLoading(true);
    setError(null);
    try {
      await axios.delete(`/api/books/${bookId}`, {
        withCredentials: true
      });

      setBooks(prev => prev.filter(book => book.id !== bookId));
      return { success: true };
    } catch (err) {
      const errorMsg = err.response?.data?.error || 'Failed to delete book';
      setError(errorMsg);
      return { success: false, error: errorMsg };
    } finally {
      setLoading(false);
    }
  }, []);

  const requestBook = useCallback(async (bookId, message) => {
    setLoading(true);
    setError(null);
    try {
      const response = await axios.post('/api/book_requests', {
        book_id: bookId,
        message: message
      }, {
        withCredentials: true
      });

      // Update the book's can_request status
      setBooks(prev => prev.map(book =>
        book.id === bookId ? { ...book, can_request: false } : book
      ));

      return { success: true, request: response.data };
    } catch (err) {
      const errorMsg = err.response?.data?.error || 'Failed to request book';
      setError(errorMsg);
      return { success: false, error: errorMsg };
    } finally {
      setLoading(false);
    }
  }, []);

  const value = useMemo(() => ({
    books,
    loading,
    error,
    paginationMeta,
    fetchBooks,
    loadMoreBooks,
    searchBooks,
    getBook,
    createBook,
    updateBook,
    deleteBook,
    requestBook
  }), [books, loading, error, paginationMeta, fetchBooks, loadMoreBooks, searchBooks, getBook, createBook, updateBook, deleteBook, requestBook]);

  return (
    <BookContext.Provider value={value}>
      {children}
    </BookContext.Provider>
  );
}; 