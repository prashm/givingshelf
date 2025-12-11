import React, { useEffect, useState } from 'react';
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

  // Separate crop instance for user_images
  const {
    imgRef: userImgRef,
    canvasRef: userCanvasRef,
    showCropModal: showUserCropModal,
    originalImage: userOriginalImage,
    crop: userCrop,
    completedCrop: userCompletedCrop,
    onImageLoad: onUserImageLoad,
    onCropChange: onUserCropChange,
    onCropComplete: onUserCropComplete,
    handleCropComplete: handleUserCropComplete,
    handleUseOriginal: handleUserUseOriginal,
    openCropModal: openUserCropModal,
    closeCropModal: closeUserCropModal,
    setCrop: setUserCrop,
    setCompletedCrop: setUserCompletedCrop,
  } = useImageCrop();

  const [croppingImageIndex, setCroppingImageIndex] = useState(null);

  const isMobile = () => {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  };

  const handleImageInputChange = (e) => {
    const file = handleInputChange(e);
    if (file) {
      updateFormData({ cover_image: file });
    }
  };

  // Handle cropping for user_images
  const handleUserImageCrop = (file, index) => {
    setCroppingImageIndex(index);
    openUserCropModal(file);
  };

  const handleUserCropCompleteWithProcessing = async () => {
    const croppedFile = await handleUserCropComplete();
    if (croppedFile && croppingImageIndex !== null) {
      const newImages = [...(formData.user_images || [])];
      newImages[croppingImageIndex] = croppedFile;
      updateFormData({ user_images: newImages });
      setCroppingImageIndex(null);
    }
  };

  const handleUserUseOriginalWithProcessing = () => {
    const originalFile = handleUserUseOriginal();
    if (originalFile && croppingImageIndex !== null) {
      // Keep the original file, just close the modal
      setCroppingImageIndex(null);
    }
  };

  // Handle book selection from autocomplete
  const handleBookSelect = (book) => {
    const secureThumbnailUrl = book.thumbnail ? book.thumbnail.replace('http:', 'https:') : null;

    // Update form data with book information
    updateFormData({
      title: book.title,
      author: book.authors.join(', '),
      genre: book.categories.length > 0 ? book.categories[0] : '',
      published_year: book.publishedDate ? new Date(book.publishedDate).getFullYear() : new Date().getFullYear(),
      isbn: book.isbn || '',
      summary: book.description || '',
      cover_image: secureThumbnailUrl, // Set for display in BookForm
      // Don't overwrite condition - let user choose
    });

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
              updateFormData={updateFormData}
              onCropUserImage={handleUserImageCrop}
              imageUploadSection={
                <ImageUpload
                  formData={formData}
                  onInputChange={handleImageInputChange}
                  isMobile={isMobile()}
                />
              }
            />

            {/* Safety Tip */}
            <div className="mt-6 p-4 bg-amber-50 border border-amber-200 rounded-md">
              <p className="text-sm text-amber-800">
                <strong>Safety reminder:</strong> Your address will be shared with other signed-in book lovers if you add it here. If you prefer more privacy, skip entering an address — you can arrange a meeting or pickup through the in-app chat instead.
              </p>
            </div>

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

      {/* Image Cropping Modal for User Images - Rendered outside main container */}
      <ImageCropper
        showCropModal={showUserCropModal}
        originalImage={userOriginalImage}
        crop={userCrop}
        completedCrop={userCompletedCrop}
        imgRef={userImgRef}
        onImageLoad={onUserImageLoad}
        onCropChange={onUserCropChange}
        onCropComplete={onUserCropComplete}
        onUseCropped={handleUserCropCompleteWithProcessing}
        onUseOriginal={handleUserUseOriginalWithProcessing}
        onClose={() => {
          closeUserCropModal();
          setCroppingImageIndex(null);
        }}
      />

      {/* Hidden canvas for cropping user images */}
      <canvas
        ref={userCanvasRef}
        style={{
          display: 'none',
        }}
      />
    </>
  );
};

export default AddBook;