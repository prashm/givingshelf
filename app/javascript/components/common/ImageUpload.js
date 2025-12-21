import React, { useRef } from 'react';
import { CameraIcon, PhotoIcon, ArrowPathIcon } from '@heroicons/react/24/outline';

const ImageUpload = ({
  formData,
  croppedImage,
  onInputChange,
  onCameraCapture,
  onGallerySelect,
  isMobile,
  currentCoverImage = null,
  showCurrentImage = false,
  validationError = null,
}) => {
  const fileInputRef = useRef(null);
  const cameraInputRef = useRef(null);

  const handleCameraCapture = () => {
    if (cameraInputRef.current) {
      cameraInputRef.current.click();
    }
  };

  const handleGallerySelect = () => {
    if (fileInputRef.current) {
      fileInputRef.current.click();
    }
  };

  return (
    <div>
      <label className="block text-sm font-medium text-gray-700 mb-2">
        Cover Image {showCurrentImage ? '' : '(Optional)'}
      </label>
      
      {/* Image Display Area */}
      <div className="mb-4">
        <div className="flex gap-4">
          {/* Current Cover Image (for EditBook) */}
          {showCurrentImage && currentCoverImage && (
            <div className="relative">
              <img 
                src={currentCoverImage} 
                alt="Current cover" 
                className="w-16 h-20 sm:w-18 sm:h-24 md:w-20 md:h-28 object-cover rounded border shadow-sm"
              />
              <div className="absolute -top-1 -left-1 bg-blue-500 text-white text-xs px-1 py-0.5 rounded-full">
                Current
              </div>
            </div>
          )}
          
          {/* Uploaded Image */}
          {formData.cover_image && (
            <div className="relative">
              <img 
                src={URL.createObjectURL(formData.cover_image)} 
                alt={showCurrentImage ? "New cover" : "Uploaded cover"} 
                className="w-16 h-20 sm:w-18 sm:h-24 md:w-20 md:h-28 object-cover rounded border shadow-sm"
              />
              {croppedImage && (
                <div className="absolute -top-1 -left-1 bg-blue-500 text-white text-xs px-1 py-0.5 rounded-full">
                  Cropped
                </div>
              )}
              {!croppedImage && showCurrentImage && (
                <div className="absolute -top-1 -left-1 bg-green-500 text-white text-xs px-1 py-0.5 rounded-full">
                  New
                </div>
              )}
            </div>
          )}
          
        </div>
      </div>

      {/* Image Upload Options */}
      {isMobile ? (
        <div className="space-y-3">
          <div className="flex gap-3">
            <button
              type="button"
              onClick={handleCameraCapture}
              className="flex-1 flex items-center justify-center gap-2 bg-emerald-600 text-white px-4 py-2 rounded-md hover:bg-emerald-700 transition-colors"
            >
              <CameraIcon className="h-5 w-5" />
              Take Photo
            </button>
            <button
              type="button"
              onClick={handleGallerySelect}
              className="flex-1 flex items-center justify-center gap-2 bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 transition-colors"
            >
              <PhotoIcon className="h-5 w-5" />
              Choose from Gallery
            </button>
          </div>
          
          {/* Hidden inputs */}
          <input
            ref={cameraInputRef}
            type="file"
            accept="image/*"
            capture="environment"
            onChange={onInputChange}
            name="cover_image"
            className="hidden"
          />
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            onChange={onInputChange}
            name="cover_image"
            className="hidden"
          />
        </div>
      ) : (
        <div>
          <input
            type="file"
            accept="image/*"
            onChange={onInputChange}
            name="cover_image"
            className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
          />
        </div>
      )}
      
      <p className="mt-2 text-sm text-gray-500">
        {isMobile 
          ? "Take a photo or choose from your gallery. You can crop the image before processing!"
          : "Upload an image and crop it if needed. We'll automatically detect book details!"
        }
      </p>

      {/* Processing Status */}
    </div>
  );
};

export default ImageUpload;

