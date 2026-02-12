import { useState, useCallback } from 'react';

export const useToyForm = (initialData = {}) => {
  const [formData, setFormData] = useState({
    title: '',
    brand: '',
    age_range: '',
    condition: 'good',
    summary: '',
    personal_note: '',
    cover_image: null,
    user_images: [],
    pickup_method: '',
    pickup_address: '',
    community_group_ids: [],
    ...initialData
  });

  const [validationErrors, setValidationErrors] = useState({});

  const validateForm = useCallback(() => {
    const errors = {};
    if (!formData.title.trim()) errors.title = 'Title is required';
    if (!formData.summary.trim()) errors.summary = 'Description is required';
    if (formData.summary.trim().length < 10) errors.summary = 'Description must be at least 10 characters';
    if (formData.summary.trim().length > 1000) errors.summary = 'Description must be less than 1000 characters';
    setValidationErrors(errors);
    return Object.keys(errors).length === 0;
  }, [formData]);

  const handleInputChange = useCallback((e) => {
    const { name, value, files } = e.target;
    if (name === 'user_images') {
      const newFiles = Array.from(files || []);
      const MAX_FILE_SIZE = 5 * 1024 * 1024;
      const MAX_TOTAL_SIZE = 20 * 1024 * 1024;
      for (const file of newFiles) {
        if (file.size > MAX_FILE_SIZE) {
          setValidationErrors(prev => ({ ...prev, user_images: `"${file.name}" is too large. Maximum file size is 5MB per photo.` }));
          return null;
        }
      }
      const currentImages = formData.user_images || [];
      let currentTotalSize = 0;
      for (const img of currentImages) {
        if (img instanceof File || img instanceof Blob) currentTotalSize += img.size;
      }
      const newFilesTotalSize = newFiles.reduce((sum, file) => sum + file.size, 0);
      if (currentTotalSize + newFilesTotalSize > MAX_TOTAL_SIZE) {
        const remainingMB = ((MAX_TOTAL_SIZE - currentTotalSize) / (1024 * 1024)).toFixed(1);
        setValidationErrors(prev => ({ ...prev, user_images: `Total photo size exceeds 20MB limit. You have ${remainingMB}MB remaining.` }));
        return null;
      }
      setValidationErrors(prev => {
        const next = { ...prev };
        delete next.user_images;
        return next;
      });
      setFormData(prev => ({ ...prev, user_images: [...(prev.user_images || []), ...newFiles] }));
      return null;
    }
    setFormData(prev => ({ ...prev, [name]: value }));
    if (validationErrors[name]) {
      setValidationErrors(prev => ({ ...prev, [name]: '' }));
    }
    return null;
  }, [formData.user_images, validationErrors]);

  const updateFormData = useCallback((updates) => {
    setFormData(prev => ({ ...prev, ...updates }));
  }, []);

  const resetForm = useCallback((newData = {}) => {
    setFormData({
      title: '',
      brand: '',
      age_range: '',
      condition: 'good',
      summary: '',
      personal_note: '',
      cover_image: null,
      user_images: [],
      pickup_method: '',
      pickup_address: '',
      community_group_ids: [],
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
    resetForm
  };
};
