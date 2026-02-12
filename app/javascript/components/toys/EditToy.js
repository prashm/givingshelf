import React, { useState, useEffect } from 'react';
import { useItems } from '../../contexts/ItemContext';
import { useAuth } from '../../contexts/AuthContext';
import { useToyForm } from '../../hooks/useToyForm';
import { useImageCrop } from '../../hooks/useImageCrop';
import ToyForm from '../common/ToyForm';
import ImageCropper from '../common/ImageCropper';
import { ArrowPathIcon } from '@heroicons/react/24/outline';

const EditToy = ({ setCurrentPage, toyId }) => {
  const { currentUser } = useAuth();

  useEffect(() => {
    if (currentUser && !currentUser.profile_complete) {
      setCurrentPage('profile');
    }
  }, [currentUser, setCurrentPage]);

  if (!currentUser || !currentUser.profile_complete) {
    return null;
  }

  const { getItem, updateItem, loading, error } = useItems();
  const { formData, validationErrors, handleInputChange, validateForm, updateFormData, resetForm } = useToyForm();

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

  const [toy, setToy] = useState(null);
  const [loadingToy, setLoadingToy] = useState(true);
  const [croppingImageIndex, setCroppingImageIndex] = useState(null);
  const [existingUserImages, setExistingUserImages] = useState([]);
  const [originalUserImages, setOriginalUserImages] = useState([]);
  const [removedExistingImageIndices, setRemovedExistingImageIndices] = useState(new Set());

  useEffect(() => {
    const fetchToy = async () => {
      try {
        const toyData = await getItem(toyId);
        if (toyData) {
          setToy(toyData);
          resetForm({
            title: toyData.title || '',
            brand: toyData.brand || '',
            age_range: toyData.age_range || '',
            condition: toyData.condition || 'good',
            summary: toyData.summary || '',
            personal_note: toyData.personal_note || '',
            user_images: [],
            pickup_method: toyData.pickup_method || '',
            pickup_address: toyData.pickup_address || '',
            community_group_ids: Array.isArray(toyData.community_group_ids) ? toyData.community_group_ids : []
          });

          if (toyData.user_images_urls && toyData.user_images_urls.length > 0) {
            setExistingUserImages(toyData.user_images_urls);
            setOriginalUserImages(toyData.user_images_urls);
          } else {
            setExistingUserImages([]);
            setOriginalUserImages([]);
          }
          setRemovedExistingImageIndices(new Set());
        }
      } catch (err) {
        console.error('Error fetching toy:', err);
      } finally {
        setLoadingToy(false);
      }
    };

    if (toyId) {
      fetchToy();
    }
  }, [toyId, getItem, resetForm]);

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
    handleUserUseOriginal();
    if (croppingImageIndex !== null) {
      setCroppingImageIndex(null);
    }
  };

  const handleRemoveExistingImage = (displayIndex) => {
    const imageUrl = existingUserImages[displayIndex];
    const originalIndex = originalUserImages.findIndex(url => url === imageUrl);

    if (originalIndex !== -1) {
      setRemovedExistingImageIndices(prev => new Set([...prev, originalIndex]));
    }

    setExistingUserImages(prev => prev.filter((_, i) => i !== displayIndex));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!validateForm()) return;

    const updateData = {
      ...formData,
      remove_user_image_indices: Array.from(removedExistingImageIndices)
    };

    const result = await updateItem(toyId, updateData);
    if (result.success) {
      window.history.back();
    }
  };

  if (loadingToy) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-2xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex justify-center items-center">
            <ArrowPathIcon className="h-8 w-8 animate-spin text-emerald-600" />
            <span className="ml-2 text-gray-600">Loading toy details...</span>
          </div>
        </div>
      </div>
    );
  }

  if (!toy) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-2xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="text-center">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Toy Not Found</h2>
            <p className="text-gray-600 mb-4">The toy you&apos;re looking for doesn&apos;t exist.</p>
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
          <h2 className="text-3xl font-bold text-gray-900 mb-6 text-center">Edit Toy</h2>

          {error && (
            <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-6">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-6">
            <ToyForm
              formData={formData}
              validationErrors={validationErrors}
              onInputChange={handleInputChange}
              updateFormData={updateFormData}
              communityGroups={currentUser.community_groups || []}
              existingUserImages={existingUserImages}
              onCropUserImage={handleUserImageCrop}
              onRemoveExistingImage={handleRemoveExistingImage}
            />

            <div className="mt-6 p-4 bg-amber-50 border border-amber-200 rounded-md">
              <p className="text-sm text-amber-800">
                <strong>Safety reminder:</strong> Your address will be shared if you add it. Skip if you prefer to arrange pickup via chat.
              </p>
            </div>

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
                {loading ? 'Updating Toy...' : 'Update Toy'}
              </button>
            </div>
          </form>
        </div>
      </div>

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

      <canvas ref={userCanvasRef} style={{ display: 'none' }} />
    </>
  );
};

export default EditToy;
