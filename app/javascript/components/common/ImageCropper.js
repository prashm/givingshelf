import React from 'react';
import { XMarkIcon, CheckIcon } from '@heroicons/react/24/outline';
import ReactCrop from 'react-image-crop';
import 'react-image-crop/dist/ReactCrop.css';

const ImageCropper = ({
  showCropModal,
  originalImage,
  crop,
  completedCrop,
  imgRef,
  onImageLoad,
  onCropChange,
  onCropComplete,
  onUseCropped,
  onUseOriginal,
  onClose,
}) => {
  if (!showCropModal || !originalImage) {
    return null;
  }

  return (
    <div 
      className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-[9999] p-4"
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.75)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 9999,
        padding: '1rem'
      }}
      onClick={(e) => {
        // Prevent closing by clicking outside - user must crop the image
        e.preventDefault();
      }}
    >
      <div 
        className="bg-white rounded-lg max-w-4xl max-h-[90vh] w-full overflow-hidden shadow-2xl"
        style={{
          backgroundColor: 'white',
          borderRadius: '0.5rem',
          maxWidth: '56rem',
          maxHeight: '90vh',
          width: '100%',
          overflow: 'hidden',
          boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
          position: 'relative'
        }}
      >
        <div className="flex items-center justify-end p-4 border-b bg-gray-50">
          <button
            type="button"
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600"
          >
            <XMarkIcon className="h-6 w-6" />
          </button>
        </div>
        
        <div className="p-4">
          <div className="mb-4">
            <div className="border-2 border-dashed border-gray-300 p-4 rounded-lg">
              <ReactCrop
                key={originalImage?.name || 'crop'}
                crop={crop}
                onChange={onCropChange}
                onComplete={onCropComplete}
                minWidth={100}
                minHeight={100}
              >
                <img
                  ref={imgRef}
                  alt="Crop me"
                  src={URL.createObjectURL(originalImage)}
                  style={{ maxHeight: '400px', width: '100%' }}
                  onLoad={onImageLoad}
                />
              </ReactCrop>
            </div>
          </div>
          
          <div className="flex gap-3 justify-center">
            <button
              type="button"
              onClick={onUseOriginal}
              className="px-6 py-3 bg-gray-600 text-white rounded-md hover:bg-gray-700 flex items-center gap-2 text-base font-medium border-2 border-gray-600"
            >
              Use Original
            </button>
            <button
              type="button"
              onClick={onUseCropped}
              disabled={!completedCrop}
              className="px-6 py-3 bg-emerald-600 text-white rounded-md hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2 text-base font-medium"
            >
              <CheckIcon className="h-5 w-5" />
              Use Cropped
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ImageCropper;
