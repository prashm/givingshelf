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
    user_images: [],
    personal_note: '',
    pickup_method: '',
    pickup_address: '',
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
    } else if (name === 'user_images') {
      // Handle multiple file uploads with validation
      const newFiles = Array.from(files || []);
      const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB per file
      const MAX_TOTAL_SIZE = 20 * 1024 * 1024; // 20MB total
      
      // Validate each new file size
      for (const file of newFiles) {
        if (file.size > MAX_FILE_SIZE) {
          setValidationErrors(prev => ({
            ...prev,
            user_images: `"${file.name}" is too large. Maximum file size is 5MB per photo.`
          }));
          return null;
        }
      }
      
      // Calculate current total size
      const currentImages = formData.user_images || [];
      let currentTotalSize = 0;
      for (const img of currentImages) {
        if (img instanceof File || img instanceof Blob) {
          currentTotalSize += img.size;
        }
      }
      
      // Calculate new files total size
      const newFilesTotalSize = newFiles.reduce((sum, file) => sum + file.size, 0);
      const totalSizeAfterAdd = currentTotalSize + newFilesTotalSize;
      
      if (totalSizeAfterAdd > MAX_TOTAL_SIZE) {
        const remainingMB = ((MAX_TOTAL_SIZE - currentTotalSize) / (1024 * 1024)).toFixed(1);
        setValidationErrors(prev => ({
          ...prev,
          user_images: `Total photo size exceeds 20MB limit. You have ${remainingMB}MB remaining. Please remove some photos or select smaller images.`
        }));
        return null;
      }
      
      // Clear validation error if valid
      setValidationErrors(prev => {
        const newErrors = { ...prev };
        delete newErrors.user_images;
        return newErrors;
      });
      
      setFormData(prev => ({
        ...prev,
        user_images: [...(prev.user_images || []), ...newFiles]
      }));
      return null;
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
      user_images: [],
      personal_note: '',
      pickup_method: '',
      pickup_address: '',
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

