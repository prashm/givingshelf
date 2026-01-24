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

  const [currentCoverImage, setCurrentCoverImage] = useState(null);
  const [book, setBook] = useState(null);
  const [loadingBook, setLoadingBook] = useState(true);
  const [croppingImageIndex, setCroppingImageIndex] = useState(null);
  const [existingUserImages, setExistingUserImages] = useState([]);
  const [originalUserImages, setOriginalUserImages] = useState([]); // Keep original array for index reference
  const [removedExistingImageIndices, setRemovedExistingImageIndices] = useState(new Set());

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
            cover_image: null,
            user_images: [], // We don't populate file objects for existing images, but we can show them
            personal_note: bookData.personal_note || '',
            pickup_method: bookData.pickup_method || '',
            pickup_address: bookData.pickup_address || '',
            community_group_ids: Array.isArray(bookData.community_group_ids) ? bookData.community_group_ids : []
          });

          // Set current cover image if it exists
          if (bookData.cover_image_url) {
            setCurrentCoverImage(bookData.cover_image_url);
          } else {
            setCurrentCoverImage(null);
          }

          // Set existing user images
          if (bookData.user_images_urls && bookData.user_images_urls.length > 0) {
            setExistingUserImages(bookData.user_images_urls);
            setOriginalUserImages(bookData.user_images_urls); // Keep original for index reference
          } else {
            setExistingUserImages([]);
            setOriginalUserImages([]);
          }
          setRemovedExistingImageIndices(new Set());
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


  // Handle removing existing image
  const handleRemoveExistingImage = (displayIndex) => {
    // Find the original index in the original array
    const imageUrl = existingUserImages[displayIndex];
    const originalIndex = originalUserImages.findIndex(url => url === imageUrl);
    
    if (originalIndex !== -1) {
      // Add the original index to removed indices set
      setRemovedExistingImageIndices(prev => new Set([...prev, originalIndex]));
    }
    
    // Remove from displayed existing images
    setExistingUserImages(prev => prev.filter((_, i) => i !== displayIndex));
  };

  // Handle book selection from autocomplete
  const handleBookSelect = (book) => {
    console.log('Selected book:', book);
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

    // Prepare data for update - include removed image indices
    const updateData = {
      ...formData,
      remove_user_image_indices: Array.from(removedExistingImageIndices)
    };

    const result = await updateBook(bookId, updateData);
    if (result.success) {
      window.history.back();
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
              onClick={() => window.history.back()}
              className="px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700"
            >
              Go Back
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
            {/* Cover Image Display - Only show if no new cover image from search */}
            {currentCoverImage && !formData.cover_image && (
              <div className="mb-6">
                <div className="flex justify-center">
                  <img
                    src={currentCoverImage}
                    alt="Current book cover"
                    className="w-16 h-20 sm:w-18 sm:h-24 md:w-20 md:h-28 object-cover rounded border shadow-sm"
                    onError={(e) => {
                      console.error('Error loading cover image:', currentCoverImage);
                      e.target.style.display = 'none';
                    }}
                  />
                </div>
              </div>
            )}

            {/* Book Form Fields */}
            <BookForm
              formData={formData}
              validationErrors={validationErrors}
              onInputChange={handleInputChange}
              onBookSelect={handleBookSelect}
              currentYear={currentYear}
              yearOptions={yearOptions}
              isEditMode={true}
              existingUserImages={existingUserImages}
              updateFormData={updateFormData}
              communityGroups={currentUser.community_groups || []}
              onCropUserImage={handleUserImageCrop}
              onRemoveExistingImage={handleRemoveExistingImage}
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
                onClick={() => window.history.back()}
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

      {/* Image Cropping Modal for Cover Image - Rendered outside main container */}
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

      {/* Hidden canvas for cropping cover image */}
      <canvas
        ref={canvasRef}
        style={{
          display: 'none',
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

export default EditBook;