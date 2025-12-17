import React, { useRef, useState, useEffect } from 'react';
import { PhotoIcon, XMarkIcon, PencilSquareIcon, CameraIcon } from '@heroicons/react/24/outline';

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
  const cameraInputRef = useRef(null);
  const galleryInputRef = useRef(null);
  const menuRef = useRef(null);
  const [isDragging, setIsDragging] = useState(false);
  const [showImageSourceMenu, setShowImageSourceMenu] = useState(false);

  // Detect if device is mobile
  const isMobile = () => {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) || 
           (typeof window !== 'undefined' && window.innerWidth < 768);
  };

  const toStableFile = async (file, fallbackName) => {
    if (!file) return null;
    if (file instanceof File) {
      try {
        // Clone to memory so Android Chrome can't invalidate the underlying temp file mid-flow
        const bytes = await file.arrayBuffer();
        return new File([bytes], file.name || fallbackName, {
          type: file.type || 'application/octet-stream',
          lastModified: Date.now()
        });
      } catch (e) {
        console.warn('Failed to stabilize file (using original):', e);
        return file; // fallback
      }
    }
    if (file instanceof Blob) {
      const name = file.name || fallbackName;
      const bytes = await file.arrayBuffer();
      return new File([bytes], name, {
        type: file.type || 'application/octet-stream',
        lastModified: Date.now()
      });
    }
    return null;
  };

  const handleFileSelect = async (files) => {
    const selected = Array.from(files || []).slice(0, maxImages - images.length - existingImages.length);
    if (selected.length === 0) return;

    const stabilized = [];
    for (let i = 0; i < selected.length; i++) {
      const stable = await toStableFile(selected[i], `upload-${Date.now()}-${i + 1}.jpg`);
      if (stable) stabilized.push(stable);
    }
    if (stabilized.length > 0) {
      onImagesChange([...images, ...stabilized]);
    }
  };

  const handleAddPhotosClick = () => {
    if (isMobile()) {
      setShowImageSourceMenu(!showImageSourceMenu);
    } else {
      // On desktop, just open file picker
      fileInputRef.current?.click();
    }
  };

  const handleTakePhoto = () => {
    cameraInputRef.current?.click();
    setShowImageSourceMenu(false);
  };

  const handleChooseFromGallery = () => {
    galleryInputRef.current?.click();
    setShowImageSourceMenu(false);
  };

  // Close menu when clicking outside
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (menuRef.current && !menuRef.current.contains(event.target)) {
        setShowImageSourceMenu(false);
      }
    };

    if (showImageSourceMenu) {
      document.addEventListener('mousedown', handleClickOutside);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [showImageSourceMenu]);

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
        <div>
          {existingImages.map((url, index) => (
            <div key={`existing-${index}`} className="relative group rounded-lg border-2 border-gray-200" style={{ overflow: 'visible' }}>
              <div className="w-full h-full overflow-hidden rounded-lg">
                <img
                  src={url}
                  alt={`Existing ${index + 1}`}
                  className="img-box"
                />
              </div>

              {/* Overlay for better button visibility */}
              <div
                className="absolute inset-0 transition-opacity pointer-events-none rounded-lg opacity-0 group-hover:opacity-100"
                style={{ backgroundColor: 'rgba(0, 0, 0, 0.2)' }}
              ></div>

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
        <div>
          {images.map((file, index) => (
            <div key={index} className="relative group rounded-lg border-2 border-emerald-500" style={{ overflow: 'visible' }}>
              <div className="w-full h-full overflow-hidden rounded-lg">
                <img
                  src={URL.createObjectURL(file)}
                  alt={`Upload ${index + 1}`}
                  className="img-box"
                />
              </div>
              {/* Overlay for better button visibility */}
              <div
                className="absolute inset-0 transition-opacity pointer-events-none rounded-lg opacity-0 group-hover:opacity-100"
                style={{ backgroundColor: 'rgba(0, 0, 0, 0.2)' }}
              ></div>

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
        <div className="relative">
          <div
            onDrop={handleDrop}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            className={`border-2 border-dashed rounded-lg p-8 mt-4 text-center transition-colors ${isDragging ? 'border-emerald-500 bg-emerald-50' : 'border-gray-300'
              }`}
          >
            <PhotoIcon className="mx-auto h-12 w-12 text-gray-400" />
            <div className="mt-4">
              <button
                type="button"
                onClick={handleAddPhotosClick}
                className="text-emerald-600 hover:text-emerald-700 font-medium"
              >
                Add Photos
              </button>
              {!isMobile() && <span className="text-gray-600 ml-2"> or drag and drop</span>}
            </div>
            <p className="text-xs text-gray-500 mt-2">
              {maxImages - allImagesCount} more {maxImages - allImagesCount === 1 ? 'photo' : 'photos'} can be added
            </p>
          </div>

          {/* Mobile Image Source Menu */}
          {showImageSourceMenu && isMobile() && (
            <div 
              ref={menuRef}
              className="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 bg-white rounded-lg shadow-lg border border-gray-200 z-50 min-w-[180px]"
            >
              <button
                type="button"
                onClick={handleTakePhoto}
                className="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-gray-50 rounded-t-lg transition-colors"
              >
                <CameraIcon className="h-5 w-5 text-gray-700" />
                <span className="text-gray-700">Take Photo</span>
              </button>
              <button
                type="button"
                onClick={handleChooseFromGallery}
                className="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-gray-50 rounded-b-lg transition-colors border-t border-gray-200"
              >
                <PhotoIcon className="h-5 w-5 text-gray-700" />
                <span className="text-gray-700">Choose from Gallery</span>
              </button>
            </div>
          )}

          {/* Hidden inputs */}
          <input
            ref={fileInputRef}
            type="file"
            multiple
            accept="image/*"
            className="hidden"
            style={{ display: 'none' }}
            onChange={(e) => handleFileSelect(e.target.files)}
          />
          <input
            ref={cameraInputRef}
            type="file"
            accept="image/*"
            capture="environment"
            className="hidden"
            style={{ display: 'none' }}
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) {
                handleFileSelect([file]);
              }
            }}
          />
          <input
            ref={galleryInputRef}
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

