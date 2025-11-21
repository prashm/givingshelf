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

  const fetchBooks = useCallback(async (params = {}) => {
    setLoading(true);
    setError(null);
    try {
      const response = await axios.get('/api/books', {
        params,
        withCredentials: true
      });
      setBooks(response.data);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to fetch books');
    } finally {
      setLoading(false);
    }
  }, []);

  const searchBooks = useCallback(async (query, zipCode) => {
    setLoading(true);
    setError(null);
    try {
      const response = await axios.get('/api/books/search', {
        params: { query, zip_code: zipCode },
        withCredentials: true
      });
      setBooks(response.data);
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
      const formData = new FormData();
      Object.keys(bookData).forEach(key => {
        if (bookData[key] !== null && bookData[key] !== undefined) {
          formData.append(`book[${key}]`, bookData[key]);
        }
      });

      const response = await axios.post('/api/books', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
        withCredentials: true
      });

      setBooks(prev => [response.data, ...prev]);
      return { success: true, book: response.data };
    } catch (err) {
      const errorMsg = err.response?.data?.errors?.join(', ') || 'Failed to create book';
      setError(errorMsg);
      return { success: false, error: errorMsg };
    } finally {
      setLoading(false);
    }
  }, []);

  const updateBook = useCallback(async (bookId, bookData) => {
    setLoading(true);
    setError(null);
    try {
      const formData = new FormData();
      Object.keys(bookData).forEach(key => {
        if (bookData[key] !== null && bookData[key] !== undefined) {
          formData.append(`book[${key}]`, bookData[key]);
        }
      });

      const response = await axios.patch(`/api/books/${bookId}`, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
        withCredentials: true
      });

      setBooks(prev => prev.map(book =>
        book.id === bookId ? response.data : book
      ));
      return { success: true, book: response.data };
    } catch (err) {
      const errorMsg = err.response?.data?.errors?.join(', ') || 'Failed to update book';
      setError(errorMsg);
      return { success: false, error: errorMsg };
    } finally {
      setLoading(false);
    }
  }, []);

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
    fetchBooks,
    searchBooks,
    getBook,
    createBook,
    updateBook,
    deleteBook,
    requestBook
  }), [books, loading, error, fetchBooks, searchBooks, getBook, createBook, updateBook, deleteBook, requestBook]);

  return (
    <BookContext.Provider value={value}>
      {children}
    </BookContext.Provider>
  );
}; 