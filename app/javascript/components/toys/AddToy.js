import React, { useEffect, useState } from 'react';
import { useItems } from '../../contexts/ItemContext';
import { useAuth } from '../../contexts/AuthContext';
import { useToyForm } from '../../hooks/useToyForm';
import { useImageCrop } from '../../hooks/useImageCrop';
import MultiImageUpload from '../common/MultiImageUpload';
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
      setCurrentPage('toys');
    }
  };

  const selectedGroupIds = Array.isArray(formData.community_group_ids)
    ? formData.community_group_ids.map((id) => parseInt(id, 10)).filter((id) => Number.isFinite(id))
    : [];
  const sortedGroups = Array.isArray(currentUser.community_groups)
    ? [...currentUser.community_groups].sort((a, b) => {
        const aZip = a?.short_name === Constants.ZIPCODE_SHORT_NAME;
        const bZip = b?.short_name === Constants.ZIPCODE_SHORT_NAME;
        if (aZip && !bZip) return -1;
        if (!aZip && bZip) return 1;
        return String(a?.name || '').localeCompare(String(b?.name || ''));
      })
    : [];

  const toggleGroup = (groupId) => {
    const id = parseInt(groupId, 10);
    if (!Number.isFinite(id)) return;
    const has = selectedGroupIds.includes(id);
    const next = has ? selectedGroupIds.filter((x) => x !== id) : [...selectedGroupIds, id];
    updateFormData({ community_group_ids: next });
  };

  const cancelTarget = (previousPage && previousPage !== 'donate') ? previousPage : 'toys';

  return (
    <>
      <div className="container mx-auto py-8 px-4 max-w-2xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <h2 className="text-3xl font-bold text-gray-900 mb-6 text-center">Add a New Toy</h2>

          {error && (
            <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-6">{error}</div>
          )}

          <form onSubmit={handleSubmit} className="space-y-6">
            <div>
              <label htmlFor="title" className="block text-sm font-medium text-gray-700 mb-2">Title *</label>
              <input
                type="text"
                id="title"
                name="title"
                value={formData.title}
                onChange={handleInputChange}
                className={`w-full px-3 py-2 border rounded-md shadow-sm ${validationErrors.title ? 'border-red-300' : 'border-gray-300'}`}
                placeholder="e.g., LEGO Set, Play Kitchen"
              />
              {validationErrors.title && (
                <p className="mt-1 text-sm font-semibold text-red-600 bg-red-50 px-2 py-1 rounded">{validationErrors.title}</p>
              )}
            </div>

            <div>
              <label htmlFor="brand" className="block text-sm font-medium text-gray-700 mb-2">Brand (Optional)</label>
              <input
                type="text"
                id="brand"
                name="brand"
                value={formData.brand}
                onChange={handleInputChange}
                className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm"
                placeholder="e.g., LEGO, Fisher-Price"
              />
            </div>

            <div>
              <label htmlFor="age_range" className="block text-sm font-medium text-gray-700 mb-2">Age Range (Optional)</label>
              <input
                type="text"
                id="age_range"
                name="age_range"
                value={formData.age_range}
                onChange={handleInputChange}
                className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm"
                placeholder="e.g., 3-6 years, 6+"
              />
            </div>

            <div>
              <label htmlFor="summary" className="block text-sm font-medium text-gray-700 mb-2">Description *</label>
              <textarea
                id="summary"
                name="summary"
                value={formData.summary}
                onChange={handleInputChange}
                rows={4}
                className={`w-full px-3 py-2 border rounded-md shadow-sm ${validationErrors.summary ? 'border-red-300' : 'border-gray-300'}`}
                placeholder="Describe the toy (10-1000 characters)"
              />
              <div className="flex justify-between mt-1">
                {validationErrors.summary && (
                  <p className="text-sm font-semibold text-red-600 bg-red-50 px-2 py-1 rounded">{validationErrors.summary}</p>
                )}
                <span className={`text-sm ml-auto ${formData.summary?.length > 1000 ? 'text-red-600' : 'text-gray-500'}`}>
                  {(formData.summary || '').length}/1000
                </span>
              </div>
            </div>

            <div>
              <label htmlFor="personal_note" className="block text-sm font-medium text-gray-700 mb-2">Personal Note (Optional)</label>
              <textarea
                id="personal_note"
                name="personal_note"
                value={formData.personal_note || ''}
                onChange={handleInputChange}
                rows={3}
                className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm"
                placeholder="Any notes about this toy..."
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Photos</label>
              <p className="text-xs text-gray-500 mb-2">The first photo will be used as the cover image.</p>
              <MultiImageUpload
                images={formData.user_images || []}
                existingImages={[]}
                onImagesChange={(newImages) => updateFormData({ user_images: newImages })}
                onRemoveImage={(index) => {
                  const newImages = [...(formData.user_images || [])];
                  newImages.splice(index, 1);
                  updateFormData({ user_images: newImages });
                }}
                onCropImage={handleUserImageCrop}
                maxImages={10}
              />
              {validationErrors.user_images && (
                <p className="mt-2 text-sm font-semibold text-red-600 bg-red-50 px-2 py-1 rounded">{validationErrors.user_images}</p>
              )}
            </div>

            <div>
              <label htmlFor="condition" className="block text-sm font-medium text-gray-700 mb-2">Condition *</label>
              <select
                id="condition"
                name="condition"
                value={formData.condition}
                onChange={handleInputChange}
                className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm"
              >
                <option value="excellent">Excellent</option>
                <option value="good">Good</option>
                <option value="fair">Fair</option>
                <option value="poor">Poor</option>
              </select>
            </div>

            {sortedGroups.length > 0 && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Share this toy in</label>
                <div className="border border-gray-200 rounded-md p-3 max-h-52 overflow-auto space-y-2">
                  {sortedGroups.map((g) => (
                    <label key={g.id} className="flex items-center gap-2 text-sm">
                      <input
                        type="checkbox"
                        checked={selectedGroupIds.includes(g.id)}
                        onChange={() => toggleGroup(g.id)}
                        style={{ appearance: 'auto', accentColor: 'rgb(5, 150, 105)', width: '1rem', height: '1rem', cursor: 'pointer' }}
                      />
                      <span>{g.name}</span>
                      {g.short_name === Constants.ZIPCODE_SHORT_NAME && <span className="text-xs text-gray-500">(default)</span>}
                    </label>
                  ))}
                </div>
              </div>
            )}

            <div>
              <label htmlFor="pickup_method" className="block text-sm font-medium text-gray-700 mb-2">Pickup Method</label>
              <select
                id="pickup_method"
                name="pickup_method"
                value={formData.pickup_method || ''}
                onChange={(e) => {
                  handleInputChange(e);
                  if (e.target.value === 'meet_in_person') updateFormData({ pickup_address: '' });
                }}
                className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm"
              >
                <option value="">Select pickup method...</option>
                <option value="meet_in_person">Meet in person</option>
                <option value="pickup_little_library_drop">Pickup little library drop</option>
                <option value="pickup_porch_drop">Pickup porch drop</option>
              </select>
            </div>

            {formData.pickup_method && (
              <div>
                <label htmlFor="pickup_address" className="block text-sm font-medium text-gray-700 mb-2">Pickup Address</label>
                <textarea
                  id="pickup_address"
                  name="pickup_address"
                  value={formData.pickup_address || ''}
                  onChange={handleInputChange}
                  rows={3}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm"
                  placeholder="Enter the address for pickup"
                />
              </div>
            )}

            <div className="mt-6 p-4 bg-amber-50 border border-amber-200 rounded-md">
              <p className="text-sm text-amber-800">
                <strong>Safety reminder:</strong> Your address will be shared if you add it. Skip if you prefer to arrange pickup via chat.
              </p>
            </div>

            <div className="flex gap-4 pt-4">
              <button
                type="button"
                onClick={() => setCurrentPage(cancelTarget)}
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
