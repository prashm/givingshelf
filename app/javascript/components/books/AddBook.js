import React, { useEffect } from 'react';
import { useBooks } from '../../contexts/BookContext';
import { useAuth } from '../../contexts/AuthContext';
import { useBookForm } from '../../hooks/useBookForm';
import { useImageCrop } from '../../hooks/useImageCrop';
import ImageUpload from '../common/ImageUpload';
import ImageCropper from '../common/ImageCropper';
import BookForm from '../common/BookForm';

const AddBook = ({ setCurrentPage, setRedirectReason }) => {
  const { currentUser } = useAuth();
  
  // Check if user is authenticated and profile is complete
  useEffect(() => {
    if (!currentUser) {
      // User is not authenticated, redirect to login
      setCurrentPage('login');
      return;
    }
    
    if (currentUser && !currentUser.profile_complete) {
      // User is authenticated but profile is incomplete, redirect to profile
      setRedirectReason('Please complete your profile to donate a book. Your profile must include your name and ZIP code.');
      setCurrentPage('profile');
    }
  }, [currentUser, setCurrentPage, setRedirectReason]);
  
  // Don't render if user is not authenticated or profile is incomplete
  if (!currentUser || !currentUser.profile_complete) {
    return null;
  }

  const { createBook, loading, error } = useBooks();
  const { formData, validationErrors, handleInputChange, validateForm, updateFormData } = useBookForm();
  const {
    imgRef,
    canvasRef,
    showCropModal,
    originalImage,
    crop,
    completedCrop,
    croppedImage,
    onImageLoad,
    onCropChange,
    onCropComplete,
    handleCropComplete,
    handleUseOriginal,
    openCropModal,
    closeCropModal,
    setCrop,
    setCompletedCrop,
  } = useImageCrop();

  const isMobile = () => {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  };

  const handleImageInputChange = (e) => {
    const file = handleInputChange(e);
    if (file) {
      openCropModal(file);
    }
  };

  const handleCropCompleteWithProcessing = async () => {
    const croppedFile = await handleCropComplete();
    if (croppedFile) {
      updateFormData({ cover_image: croppedFile });
    }
  };

  const handleUseOriginalWithProcessing = () => {
    const originalFile = handleUseOriginal();
    if (originalFile) {
      updateFormData({ cover_image: originalFile });
    }
  };

  // Handle book selection from autocomplete
  const handleBookSelect = (book) => {
    
    // Update form data with book information
    updateFormData({
      title: book.title,
      author: book.authors.join(', '),
      genre: book.categories.length > 0 ? book.categories[0] : '',
      published_year: book.publishedDate ? new Date(book.publishedDate).getFullYear() : new Date().getFullYear(),
      isbn: book.isbn || '',
      summary: book.description || '',
      api_cover_image: book.thumbnail || null, // Store API cover image URL
      // Don't overwrite condition - let user choose
    });

    // If book has a cover image, we could potentially fetch and set it
    // For now, we'll let the user upload their own image
    if (book.thumbnail) {
      console.log('Book cover available:', book.thumbnail);
      // You could implement cover image fetching here if needed
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!validateForm()) return;

    const result = await createBook(formData);
    if (result.success) {
      setCurrentPage('home');
    }
  };

  const currentYear = new Date().getFullYear();
  const yearOptions = Array.from({ length: currentYear - 1799 }, (_, i) => currentYear - i);

  return (
    <>
      <div className="container mx-auto py-8 px-4 max-w-2xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <h2 className="text-3xl font-bold text-gray-900 mb-6 text-center">Add a New Book</h2>
          
          {error && (
            <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-6">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Book Form Fields */}
            <BookForm
              formData={formData}
              validationErrors={validationErrors}
              onInputChange={handleInputChange}
              onBookSelect={handleBookSelect}
              currentYear={currentYear}
              yearOptions={yearOptions}
              imageUploadSection={
                <ImageUpload
                  formData={formData}
                  croppedImage={croppedImage}
                  onInputChange={handleImageInputChange}
                  isMobile={isMobile()}
                />
              }
            />

            {/* Submit Button */}
            <div className="flex gap-4 pt-4">
              <button
                type="button"
                onClick={() => setCurrentPage('home')}
                className="flex-1 px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={loading}
                className="flex-1 px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-emerald-600 hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? 'Adding Book...' : 'Add Book'}
              </button>
            </div>
          </form>
        </div>
      </div>

      {/* Image Cropping Modal - Rendered outside main container */}
      <ImageCropper
        showCropModal={showCropModal}
        originalImage={originalImage}
        crop={crop}
        completedCrop={completedCrop}
        imgRef={imgRef}
        onImageLoad={onImageLoad}
        onCropChange={onCropChange}
        onCropComplete={onCropComplete}
        onUseCropped={handleCropCompleteWithProcessing}
        onUseOriginal={handleUseOriginalWithProcessing}
        onClose={closeCropModal}
      />

      {/* Hidden canvas for cropping */}
      <canvas
        ref={canvasRef}
        style={{
          display: 'none',
        }}
      />
    </>
  );
};

export default AddBook;