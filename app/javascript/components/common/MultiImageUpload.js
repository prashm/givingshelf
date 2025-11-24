import React, { useRef, useState } from 'react';
import { PhotoIcon, XMarkIcon, PencilSquareIcon } from '@heroicons/react/24/outline';

const MultiImageUpload = ({ 
  images = [], 
  existingImages = [], 
  onImagesChange, 
  onRemoveImage,
  onRemoveExisting,
  onCropImage,
  onCropExisting,
  maxImages = 10
}) => {
  const fileInputRef = useRef(null);
  const [isDragging, setIsDragging] = useState(false);

  const handleFileSelect = (files) => {
    const newFiles = Array.from(files).slice(0, maxImages - images.length - existingImages.length);
    if (newFiles.length > 0) {
      onImagesChange([...images, ...newFiles]);
    }
  };

  const handleDrop = (e) => {
    e.preventDefault();
    setIsDragging(false);
    const files = e.dataTransfer.files;
    handleFileSelect(files);
  };

  const handleDragOver = (e) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = (e) => {
    e.preventDefault();
    setIsDragging(false);
  };

  const allImagesCount = images.length + existingImages.length;
  const canAddMore = allImagesCount < maxImages;

  return (
    <div className="space-y-4">
      <label className="block text-sm font-medium text-gray-700">
        Photos ({allImagesCount}/{maxImages})
      </label>
      
      {/* Existing Images Grid */}
      {existingImages.length > 0 && (
        <div className="grid grid-cols-6 gap-2">
          {existingImages.map((url, index) => (
            <div key={`existing-${index}`} className="relative group aspect-square rounded-lg border-2 border-gray-200" style={{ overflow: 'visible' }}>
              <div className="w-full h-full overflow-hidden rounded-lg">
                <img
                  src={url}
                  alt={`Existing ${index + 1}`}
                  className="img-box"
                />
              </div>
              {/* Action buttons - Top right corner */}
              <div className="absolute flex gap-1" style={{ top: '4px', right: '4px', zIndex: 100 }}>
                {onCropExisting && (
                  <button
                    type="button"
                    onClick={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      onCropExisting(url, index);
                    }}
                    className="bg-blue-600 text-white rounded-full hover:bg-blue-700 transition-all shadow-2xl flex items-center justify-center border-2 border-white"
                    title="Crop image"
                    style={{ 
                      width: '36px',
                      height: '36px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center'
                    }}
                  >
                    <PencilSquareIcon className="h-5 w-5" style={{ display: 'block' }} />
                  </button>
                )}
                {onRemoveExisting && (
                  <button
                    type="button"
                    onClick={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      onRemoveExisting(index);
                    }}
                    className="bg-red-600 text-white rounded-full hover:bg-red-700 transition-all shadow-2xl flex items-center justify-center border-2 border-white"
                    title="Remove image"
                    style={{ 
                      width: '36px',
                      height: '36px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center'
                    }}
                  >
                    <XMarkIcon className="h-5 w-5" style={{ display: 'block' }} />
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* New Images Grid */}
      {images.length > 0 && (
        <div className="grid grid-cols-6 gap-2">
          {images.map((file, index) => (
            <div key={index} className="relative group aspect-square rounded-lg border-2 border-emerald-500" style={{ overflow: 'visible' }}>
              <div className="w-full h-full overflow-hidden rounded-lg">
                <img
                  src={URL.createObjectURL(file)}
                  alt={`Upload ${index + 1}`}
                  className="img-box"
                />
              </div>
              {/* Overlay for better button visibility */}
              <div className="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-20 transition-opacity pointer-events-none rounded-lg"></div>
              
              {/* Action buttons - Top right corner */}
              <div className="absolute flex gap-1" style={{ top: '4px', right: '4px', zIndex: 100 }}>
                {onCropImage ? (
                  <button
                    type="button"
                    onClick={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      onCropImage(file, index);
                    }}
                    className="bg-blue-600 text-white rounded-full hover:bg-blue-700 transition-all shadow-2xl flex items-center justify-center border-2 border-white"
                    title="Crop image"
                    style={{ 
                      width: '36px',
                      height: '36px',
                      padding: '0',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      position: 'relative'
                    }}
                  >
                    <PencilSquareIcon className="h-5 w-5" />
                  </button>
                ) : null}
                <button
                  type="button"
                  onClick={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    onRemoveImage(index);
                  }}
                  className="bg-red-600 text-white rounded-full hover:bg-red-700 transition-all shadow-2xl flex items-center justify-center border-2 border-white"
                  title="Remove image"
                  style={{ 
                    width: '36px',
                    height: '36px',
                    padding: '0',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    position: 'relative'
                  }}
                >
                  <XMarkIcon className="h-5 w-5" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Add More Button */}
      {canAddMore && (
        <div
          onDrop={handleDrop}
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          className={`border-2 border-dashed rounded-lg p-8 mt-4 text-center transition-colors ${
            isDragging ? 'border-emerald-500 bg-emerald-50' : 'border-gray-300'
          }`}
        >
          <PhotoIcon className="mx-auto h-12 w-12 text-gray-400" />
          <div className="mt-4">
            <button
              type="button"
              onClick={() => fileInputRef.current?.click()}
              className="text-emerald-600 hover:text-emerald-700 font-medium"
            >
              Add Photos
            </button>
            <span className="text-gray-600 ml-2"> or drag and drop</span>
          </div>
          <p className="text-xs text-gray-500 mt-2">
            {maxImages - allImagesCount} more {maxImages - allImagesCount === 1 ? 'photo' : 'photos'} can be added
          </p>
          <input
            ref={fileInputRef}
            type="file"
            multiple
            accept="image/*"
            className="hidden"
            style={{ display: 'none' }}
            onChange={(e) => handleFileSelect(e.target.files)}
          />
        </div>
      )}
    </div>
  );
};

export default MultiImageUpload;

