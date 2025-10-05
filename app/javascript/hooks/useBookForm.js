import { useState, useCallback } from 'react';

export const useBookForm = (initialData = {}) => {
  const [formData, setFormData] = useState({
    title: '',
    author: '',
    condition: 'good',
    summary: '',
    genre: '',
    published_year: new Date().getFullYear(),
    isbn: '',
    cover_image: null,
    ...initialData
  });

  const [validationErrors, setValidationErrors] = useState({});

  const validateForm = useCallback(() => {
    const errors = {};
    
    if (!formData.title.trim()) errors.title = 'Title is required';
    if (!formData.author.trim()) errors.author = 'Author is required';
    if (!formData.summary.trim()) errors.summary = 'Summary is required';
    if (formData.summary.trim().length < 10) errors.summary = 'Summary must be at least 10 characters';
    if (formData.summary.trim().length > 1000) errors.summary = 'Summary must be less than 1000 characters';
    if (!formData.genre.trim()) errors.genre = 'Genre is required';
    if (!formData.published_year) errors.published_year = 'Published year is required';
    if (formData.published_year < 1800 || formData.published_year > new Date().getFullYear()) {
      errors.published_year = `Published year must be between 1800 and ${new Date().getFullYear()}`;
    }
    if (formData.isbn && !/^\d{10}(\d{3})?$/.test(formData.isbn.replace(/-/g, ''))) {
      errors.isbn = 'ISBN must be 10 or 13 digits';
    }

    setValidationErrors(errors);
    return Object.keys(errors).length === 0;
  }, [formData]);

  const handleInputChange = useCallback((e) => {
    const { name, value, files } = e.target;
    
    if (name === 'cover_image') {
      const file = files[0];
      if (file) {
        setFormData(prev => ({ ...prev, [name]: file }));
        return file; // Return file for cropping
      }
    } else {
      setFormData(prev => ({ ...prev, [name]: value }));
    }
    
    // Clear validation error when user starts typing
    if (validationErrors[name]) {
      setValidationErrors(prev => ({ ...prev, [name]: '' }));
    }
    
    return null;
  }, [validationErrors]);

  const updateFormData = useCallback((updates) => {
    setFormData(prev => ({ ...prev, ...updates }));
  }, []);

  const resetForm = useCallback((newData = {}) => {
    setFormData({
      title: '',
      author: '',
      condition: 'good',
      summary: '',
      genre: '',
      published_year: new Date().getFullYear(),
      isbn: '',
      cover_image: null,
      ...newData
    });
    setValidationErrors({});
  }, []);

  return {
    formData,
    validationErrors,
    handleInputChange,
    updateFormData,
    validateForm,
    resetForm,
  };
};

