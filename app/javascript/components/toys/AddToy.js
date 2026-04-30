import React, { useEffect, useState } from 'react';
import { useItems } from '../../contexts/ItemContext';
import { useAuth } from '../../contexts/AuthContext';
import { useToyForm } from '../../hooks/useToyForm';
import { useImageCrop } from '../../hooks/useImageCrop';
import ToyForm from '../common/ToyForm';
import ImageCropper from '../common/ImageCropper';
import { parsePageFromPath } from '../../lib/textUtils';
import * as Constants from '../../lib/constants';

const AddToy = ({ setCurrentPage, setRedirectReason, previousPage }) => {
  const { currentUser } = useAuth();
  const { createItem, loading, error } = useItems();
  const { formData, validationErrors, handleInputChange, validateForm, updateFormData } = useToyForm();

  useEffect(() => {
    if (!currentUser) {
      setCurrentPage('login');
      return;
    }
    if (currentUser && !currentUser.profile_complete) {
      setRedirectReason('Please complete your profile to donate a toy.');
      setCurrentPage('profile');
    }
  }, [currentUser, setCurrentPage, setRedirectReason]);

  if (!currentUser || !currentUser.profile_complete) return null;

  useEffect(() => {
    if (!currentUser?.community_groups) return;
    if (Array.isArray(formData.community_group_ids) && formData.community_group_ids.length > 0) return;
    const zipGroup = currentUser.community_groups.find((g) => g.short_name === Constants.ZIPCODE_SHORT_NAME);
    const selected = zipGroup?.id ? [zipGroup.id] : [];
    const parsed = parsePageFromPath(window.location.pathname);
    if (parsed?.page === 'groupLanding' && parsed.groupShortName) {
      const fromGroup = currentUser.community_groups.find((g) => g.short_name === parsed.groupShortName);
      if (fromGroup?.id && !selected.includes(fromGroup.id)) selected.push(fromGroup.id);
    }
    updateFormData({ community_group_ids: selected });
  }, [currentUser?.id]);

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

  const navigateAfterComplete = () => {
    const parsed = parsePageFromPath(window.location.pathname);
    if (parsed.page === 'groupBrowse' && parsed.groupShortName && parsed.itemType) {
      setCurrentPage('groupBrowse', { groupShortName: parsed.groupShortName, itemType: parsed.itemType });
    } else if (parsed.page === 'groupLanding' && parsed.groupShortName) {
      setCurrentPage('groupLanding', { groupShortName: parsed.groupShortName });
    } else if (parsed.page === 'books' || parsed.page === 'toys') {
      setCurrentPage(parsed.page);
    } else {
      setCurrentPage('toys');
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validateForm()) return;

    const userImages = formData.user_images || [];
    const submitData = {
      ...formData,
      cover_image: userImages[0] || null,
      user_images: userImages,
    };

    const result = await createItem(submitData);
    if (result.success) {
      navigateAfterComplete();
    }
  };

  return (
    <>
      <div className="container mx-auto py-8 px-4 max-w-2xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <h2 className="text-3xl font-bold text-gray-900 mb-6 text-center">Add a New Toy</h2>

          {error && (
            <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-6">{error}</div>
          )}

          <form onSubmit={handleSubmit} className="space-y-6">
            <ToyForm
              formData={formData}
              validationErrors={validationErrors}
              onInputChange={handleInputChange}
              updateFormData={updateFormData}
              communityGroups={currentUser.community_groups || []}
              onCropUserImage={handleUserImageCrop}
            />

            <div className="flex gap-4 pt-4">
              <button
                type="button"
                onClick={navigateAfterComplete}
                className="flex-1 px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={loading}
                className="flex-1 px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? 'Adding Toy...' : 'Add Toy'}
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
        onUseOriginal={handleUserUseOriginal}
        onClose={() => { closeUserCropModal(); setCroppingImageIndex(null); }}
      />
      <canvas ref={userCanvasRef} style={{ display: 'none' }} />
    </>
  );
};

export default AddToy;
