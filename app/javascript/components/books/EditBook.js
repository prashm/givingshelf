import React, { useState, useEffect } from 'react';
import { useBooks } from '../../contexts/BookContext';
import { useAuth } from '../../contexts/AuthContext';
import { useBookForm } from '../../hooks/useBookForm';
import { useImageCrop } from '../../hooks/useImageCrop';
import ImageUpload from '../common/ImageUpload';
import ImageCropper from '../common/ImageCropper';
import BookForm from '../common/BookForm';
import { ArrowPathIcon } from '@heroicons/react/24/outline';

const EditBook = ({ setCurrentPage, bookId }) => {
  const { currentUser } = useAuth();
  
  // Check if profile is complete, redirect if not
  useEffect(() => {
    if (currentUser && !currentUser.profile_complete) {
      setCurrentPage('profile');
    }
  }, [currentUser, setCurrentPage]);
  
  // Don't render if user is not authenticated or profile is incomplete
  if (!currentUser || !currentUser.profile_complete) {
    return null;
  }

  const { getBook, updateBook, loading, error } = useBooks();
  const { formData, validationErrors, handleInputChange, validateForm, updateFormData, resetForm } = useBookForm();
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

  const [currentCoverImage, setCurrentCoverImage] = useState(null);
  const [book, setBook] = useState(null);
  const [loadingBook, setLoadingBook] = useState(true);

  const isMobile = () => {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  };

  useEffect(() => {
    const fetchBook = async () => {
      try {
        const bookData = await getBook(bookId);
        if (bookData) {
          setBook(bookData);
          resetForm({
            title: bookData.title || '',
            author: bookData.author || '',
            condition: bookData.condition || 'good',
            summary: bookData.summary || '',
            genre: bookData.genre || '',
            published_year: bookData.published_year || new Date().getFullYear(),
            isbn: bookData.isbn || '',
            cover_image: null
          });
          
          // Set current cover image if it exists
          if (bookData.cover_image_url) {
            setCurrentCoverImage(bookData.cover_image_url);
          }
        }
      } catch (err) {
        console.error('Error fetching book:', err);
      } finally {
        setLoadingBook(false);
      }
    };

    if (bookId) {
      fetchBook();
    }
  }, [bookId, getBook, resetForm]);

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

  // Handle book selection from autocomplete
  const handleBookSelect = (book) => {
    console.log('Selected book:', book);
    
    // Update form data with book information
    updateFormData({
      title: book.title,
      author: book.authors.join(', '),
      genre: book.categories.length > 0 ? book.categories[0] : '',
      published_year: book.publishedDate ? new Date(book.publishedDate).getFullYear() : new Date().getFullYear(),
      isbn: book.isbn || '',
      summary: book.description || '',
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

    const result = await updateBook(bookId, formData);
    if (result.success) {
      setCurrentPage('home');
    }
  };

  const currentYear = new Date().getFullYear();
  const yearOptions = Array.from({ length: currentYear - 1799 }, (_, i) => currentYear - i);

  if (loadingBook) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-2xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center justify-center">
            <ArrowPathIcon className="h-8 w-8 animate-spin text-emerald-600" />
            <span className="ml-2 text-gray-600">Loading book details...</span>
          </div>
        </div>
      </div>
    );
  }

  if (!book) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-2xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="text-center">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Book Not Found</h2>
            <p className="text-gray-600 mb-4">The book you're looking for doesn't exist.</p>
            <button
              onClick={() => setCurrentPage('home')}
              className="px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700"
            >
              Back to Home
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <>
      <div className="container mx-auto py-8 px-4 max-w-2xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <h2 className="text-3xl font-bold text-gray-900 mb-6 text-center">Edit Book</h2>
          
          {error && (
            <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-6">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Cover Image Section */}
            <ImageUpload
              formData={formData}
              croppedImage={croppedImage}
              onInputChange={handleImageInputChange}
              isMobile={isMobile()}
              currentCoverImage={currentCoverImage}
              showCurrentImage={true}
            />

            {/* Book Form Fields */}
            <BookForm
              formData={formData}
              validationErrors={validationErrors}
              onInputChange={handleInputChange}
              onBookSelect={handleBookSelect}
              currentYear={currentYear}
              yearOptions={yearOptions}
              isEditMode={true}
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
                {loading ? 'Updating Book...' : 'Update Book'}
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

export default EditBook;