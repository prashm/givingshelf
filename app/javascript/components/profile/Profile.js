import React, { useState, useEffect, useRef } from 'react';
import { UserIcon, EnvelopeIcon, PhoneIcon, MapPinIcon, PencilIcon, CameraIcon } from '@heroicons/react/24/outline';
import { useAuth } from '../../contexts/AuthContext';
import { useImageCrop } from '../../hooks/useImageCrop';
import ImageCropper from '../common/ImageCropper';

const Profile = ({ currentUser, setCurrentPage, redirectReason, clearRedirectReason }) => {
  const { updateProfile } = useAuth();
  const [isEditing, setIsEditing] = useState(false);
  const [formData, setFormData] = useState({
    first_name: '',
    last_name: '',
    email: '',
    phone: '',
    zip_code: ''
  });
  const [errors, setErrors] = useState({});
  const [isSaving, setIsSaving] = useState(false);
  const [profilePicture, setProfilePicture] = useState(null);
  const [profilePicturePreview, setProfilePicturePreview] = useState(null);
  const fileInputRef = useRef(null);

  // Image cropping hook
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

  // Format US phone number
  const formatPhoneNumber = (value) => {
    // Remove all non-digits
    const digits = value.replace(/\D/g, '');
    
    // Limit to 10 digits (US phone number)
    const limitedDigits = digits.slice(0, 10);
    
    // Format as (XXX) XXX-XXXX
    if (limitedDigits.length === 0) return '';
    if (limitedDigits.length <= 3) return `(${limitedDigits}`;
    if (limitedDigits.length <= 6) return `(${limitedDigits.slice(0, 3)}) ${limitedDigits.slice(3)}`;
    return `(${limitedDigits.slice(0, 3)}) ${limitedDigits.slice(3, 6)}-${limitedDigits.slice(6)}`;
  };

  // Validate US phone number format
  const validatePhoneNumber = (phone) => {
    if (!phone || !phone.trim()) return true; // Phone is optional
    const digits = phone.replace(/\D/g, '');
    return digits.length === 10; // US phone number should have 10 digits
  };

  useEffect(() => {
    if (currentUser) {
      // Format phone number if it exists
      const formattedPhone = currentUser.phone ? formatPhoneNumber(currentUser.phone) : '';
      
      setFormData({
        first_name: currentUser.first_name || '',
        last_name: currentUser.last_name || '',
        email: currentUser.email_address || '',
        phone: formattedPhone,
        zip_code: currentUser.zip_code || ''
      });

      // Set profile picture preview if exists
      // Only update if we don't have a pending upload (blob URL)
      // This prevents overwriting the preview while user is cropping
      if (!profilePicture) {
        if (currentUser.profile_picture_url) {
          // Clean up any old blob URL before setting new one
          if (profilePicturePreview && profilePicturePreview.startsWith('blob:')) {
            URL.revokeObjectURL(profilePicturePreview);
          }
          setProfilePicturePreview(currentUser.profile_picture_url);
        } else {
          // Clean up blob URL if exists
          if (profilePicturePreview && profilePicturePreview.startsWith('blob:')) {
            URL.revokeObjectURL(profilePicturePreview);
          }
          setProfilePicturePreview(null);
        }
      }
      
      // If profile is incomplete, automatically enter edit mode
      if (currentUser && !currentUser.profile_complete) {
        setIsEditing(true);
      }
    }
  }, [currentUser, profilePicture]);

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    let formattedValue = value;
    
    // Format phone number as user types
    if (name === 'phone') {
      formattedValue = formatPhoneNumber(value);
    }
    
    setFormData(prev => ({ ...prev, [name]: formattedValue }));
  };

  const handleImageInputChange = (e) => {
    const file = e.target.files?.[0];
    if (file) {
      // Validate file type
      if (!file.type.startsWith('image/')) {
        setErrors(prev => ({ ...prev, profile_picture: 'Please select an image file' }));
        return;
      }
      
      // Validate file size (max 5MB)
      if (file.size > 5 * 1024 * 1024) {
        setErrors(prev => ({ ...prev, profile_picture: 'Image size must be less than 5MB' }));
        return;
      }

      setErrors(prev => {
        const newErrors = { ...prev };
        delete newErrors.profile_picture;
        return newErrors;
      });

      // Open crop modal
      openCropModal(file);
    }
    // Reset input value so same file can be selected again
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const handleCropCompleteWithProcessing = async () => {
    const croppedFile = await handleCropComplete();
    if (croppedFile) {
      setProfilePicture(croppedFile);
      setProfilePicturePreview(URL.createObjectURL(croppedFile));
    }
  };

  const handleUseOriginalWithProcessing = () => {
    const originalFile = handleUseOriginal();
    if (originalFile) {
      setProfilePicture(originalFile);
      setProfilePicturePreview(URL.createObjectURL(originalFile));
    }
  };

  const handleRemoveProfilePicture = () => {
    // Clean up blob URL if it exists
    if (profilePicturePreview && profilePicturePreview.startsWith('blob:')) {
      URL.revokeObjectURL(profilePicturePreview);
    }
    setProfilePicture(null);
    setProfilePicturePreview(null);
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const validateForm = () => {
    const newErrors = {};
    
    if (!formData.first_name.trim()) {
      newErrors.first_name = 'First name is required';
    } else if (formData.first_name.trim().length < 2) {
      newErrors.first_name = 'First name must be at least 2 characters';
    }
    
    if (!formData.last_name.trim()) {
      newErrors.last_name = 'Last name is required';
    } else if (formData.last_name.trim().length < 2) {
      newErrors.last_name = 'Last name must be at least 2 characters';
    }
    
    if (!formData.zip_code.trim()) {
      newErrors.zip_code = 'ZIP code is required';
    } else if (!/^\d{5}(-\d{4})?$/.test(formData.zip_code.trim())) {
      newErrors.zip_code = 'Please enter a valid US ZIP code';
    }
    
    // Phone is optional, but if provided, must be valid US format
    if (formData.phone.trim() && !validatePhoneNumber(formData.phone)) {
      newErrors.phone = 'Please enter a valid US phone number (10 digits)';
    }
    
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!validateForm()) {
      return;
    }
    
    setIsSaving(true);
    
    try {
      // Format phone number before sending (remove formatting, keep only digits)
      const phoneDigits = formData.phone.replace(/\D/g, '');
      
      const userData = {
        first_name: formData.first_name.trim(),
        last_name: formData.last_name.trim(),
        zip_code: formData.zip_code.trim(),
        phone: phoneDigits || null // Send null if empty
      };

      // If profile picture was removed (null and no preview), send empty string to remove it
      // Otherwise send the new profile picture if it exists
      const profilePictureToSend = profilePicture;
      
      const result = await updateProfile(userData, profilePictureToSend);
      
      if (result.success) {
        // Clean up blob URL before clearing
        if (profilePicturePreview && profilePicturePreview.startsWith('blob:')) {
          URL.revokeObjectURL(profilePicturePreview);
        }
        
        setProfilePicture(null); // Clear the new profile picture after successful save
        
        // Update preview immediately from the response if available
        if (result.user?.profile_picture_url) {
          setProfilePicturePreview(result.user.profile_picture_url);
        } else if (result.user && !result.user.profile_picture_url) {
          setProfilePicturePreview(null);
        }
        
        setIsEditing(false);
        setErrors({});
        
        // Clear redirect reason after successful save
        if (clearRedirectReason) {
          clearRedirectReason();
        }
      } else {
        setErrors({ submit: result.error || 'Failed to update profile' });
      }
    } catch (error) {
      setErrors({ submit: 'An error occurred. Please try again.' });
    } finally {
      setIsSaving(false);
    }
  };

  const handleCancel = () => {
    setIsEditing(false);
    setErrors({});
    setProfilePicture(null); // Clear any new profile picture
    // Reset form data to original values
    if (currentUser) {
      const formattedPhone = currentUser.phone ? formatPhoneNumber(currentUser.phone) : '';
      setFormData({
        first_name: currentUser.first_name || '',
        last_name: currentUser.last_name || '',
        email: currentUser.email_address || '',
        phone: formattedPhone,
        zip_code: currentUser.zip_code || ''
      });
      // Reset profile picture preview
      if (currentUser.profile_picture_url) {
        setProfilePicturePreview(currentUser.profile_picture_url);
      } else {
        setProfilePicturePreview(null);
      }
    }
  };

  if (!currentUser) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-2xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="text-center">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Profile Not Available</h2>
            <p className="text-gray-600 mb-4">Please log in to view your profile.</p>
            <button
              onClick={() => setCurrentPage('login')}
              className="px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700"
            >
              Log In
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto py-8 px-4 max-w-2xl">
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-3xl font-bold text-gray-900">My Profile</h2>
          {!isEditing && (
            <button
              onClick={() => setIsEditing(true)}
              className="flex items-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700 transition-colors"
            >
              <PencilIcon className="h-4 w-4" />
              Edit Profile
            </button>
          )}
        </div>

        {/* Redirect Reason Message */}
        {redirectReason && (
          <div className="mb-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
            <div className="flex items-start">
              <div className="flex-shrink-0">
                <svg className="h-5 w-5 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
                </svg>
              </div>
              <div className="ml-3 flex-1">
                <p className="text-sm text-blue-800">{redirectReason}</p>
              </div>
              <button
                onClick={clearRedirectReason}
                className="ml-3 flex-shrink-0 text-blue-600 hover:text-blue-800"
              >
                <svg className="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
                </svg>
              </button>
            </div>
          </div>
        )}

        {isEditing ? (
          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Profile Picture */}
            <div className="text-center">
              <div className="relative inline-block mb-4">
                {profilePicturePreview ? (
                  <img
                    src={profilePicturePreview}
                    alt="Profile"
                    className="w-24 h-24 rounded-full object-cover border-4 border-gray-200"
                  />
                ) : (
                  <div className="w-24 h-24 bg-gray-200 rounded-full flex items-center justify-center border-4 border-gray-200">
                    <UserIcon className="w-12 h-12 text-gray-400" />
                  </div>
                )}
                <button
                  type="button"
                  onClick={() => fileInputRef.current?.click()}
                  className="absolute bottom-0 right-0 bg-emerald-600 text-white rounded-full p-2 hover:bg-emerald-700 transition-colors shadow-lg"
                  title="Change profile picture"
                >
                  <CameraIcon className="h-4 w-4" />
                </button>
              </div>
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                onChange={handleImageInputChange}
                className="hidden"
              />
              {profilePicturePreview && (
                <button
                  type="button"
                  onClick={handleRemoveProfilePicture}
                  className="text-sm text-red-600 hover:text-red-700"
                >
                  Remove picture
                </button>
              )}
              {errors.profile_picture && (
                <p className="mt-1 text-sm text-red-600">{errors.profile_picture}</p>
              )}
              <p className="text-xs text-gray-500 mt-2">Click the camera icon to upload a new profile picture</p>
            </div>

            {/* Error Message */}
            {errors.submit && (
              <div className="bg-red-50 border border-red-200 rounded-md p-3">
                <p className="text-red-600 text-sm">{errors.submit}</p>
              </div>
            )}

            {/* First Name */}
            <div>
              <label htmlFor="first_name" className="block text-sm font-medium text-gray-700 mb-2">
                First Name *
              </label>
              <input
                type="text"
                id="first_name"
                name="first_name"
                value={formData.first_name}
                onChange={handleInputChange}
                className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${
                  errors.first_name ? 'border-red-500' : 'border-gray-300'
                }`}
                placeholder="Enter your first name"
              />
              {errors.first_name && (
                <p className="mt-1 text-sm text-red-600">{errors.first_name}</p>
              )}
            </div>

            {/* Last Name */}
            <div>
              <label htmlFor="last_name" className="block text-sm font-medium text-gray-700 mb-2">
                Last Name *
              </label>
              <input
                type="text"
                id="last_name"
                name="last_name"
                value={formData.last_name}
                onChange={handleInputChange}
                className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${
                  errors.last_name ? 'border-red-500' : 'border-gray-300'
                }`}
                placeholder="Enter your last name"
              />
              {errors.last_name && (
                <p className="mt-1 text-sm text-red-600">{errors.last_name}</p>
              )}
            </div>

            {/* Email (read-only) */}
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-2">
                Email Address
              </label>
              <input
                type="email"
                id="email"
                name="email"
                value={formData.email}
                disabled
                className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm bg-gray-100 text-gray-600 cursor-not-allowed"
              />
            </div>

            {/* Phone */}
            <div>
              <label htmlFor="phone" className="block text-sm font-medium text-gray-700 mb-2">
                Phone Number
              </label>
              <input
                type="tel"
                id="phone"
                name="phone"
                value={formData.phone}
                onChange={handleInputChange}
                className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${
                  errors.phone ? 'border-red-500' : 'border-gray-300'
                }`}
                placeholder="(123) 456-7890"
                maxLength={14}
              />
              {errors.phone && (
                <p className="mt-1 text-sm text-red-600">{errors.phone}</p>
              )}
              <p className="mt-1 text-xs text-gray-500">Optional - US format only</p>
            </div>

            {/* ZIP Code */}
            <div>
              <label htmlFor="zip_code" className="block text-sm font-medium text-gray-700 mb-2">
                ZIP Code *
              </label>
              <input
                type="text"
                id="zip_code"
                name="zip_code"
                value={formData.zip_code}
                onChange={handleInputChange}
                className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${
                  errors.zip_code ? 'border-red-500' : 'border-gray-300'
                }`}
                placeholder="Enter your ZIP code (e.g., 12345)"
              />
              {errors.zip_code && (
                <p className="mt-1 text-sm text-red-600">{errors.zip_code}</p>
              )}
            </div>

            {/* Action Buttons */}
            <div className="flex mt-4 gap-4 pt-4">
              <button
                type="button"
                onClick={handleCancel}
                className="flex-1 px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSaving}
                className="flex-1 px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-emerald-600 hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isSaving ? 'Saving...' : 'Save Changes'}
              </button>
            </div>
          </form>
        ) : (
          <div className="space-y-6">
            {/* Profile Picture */}
            <div className="text-center">
              {profilePicturePreview ? (
                <img
                  src={profilePicturePreview}
                  alt="Profile"
                  className="w-24 h-24 rounded-full object-cover border-4 border-gray-200 mx-auto mb-4"
                />
              ) : (
                <div className="w-24 h-24 bg-gray-200 rounded-full mx-auto mb-4 flex items-center justify-center border-4 border-gray-200">
                  <UserIcon className="w-12 h-12 text-gray-400" />
                </div>
              )}
            </div>

            {/* Profile Information */}
            <div className="space-y-4">
              <div className="flex items-center gap-3">
                <UserIcon className="h-5 w-5 text-gray-400" />
                <div>
                  <span className="text-sm font-medium text-gray-500">Full Name</span>
                  <p className="text-gray-900">
                    {currentUser.first_name || currentUser.last_name 
                      ? `${currentUser.first_name || ''} ${currentUser.last_name || ''}`.trim()
                      : 'Not provided'}
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-3">
                <EnvelopeIcon className="h-5 w-5 text-gray-400" />
                <div>
                  <span className="text-sm font-medium text-gray-500">Email</span>
                  <p className="text-gray-900">{currentUser.email_address || 'Not provided'}</p>
                </div>
              </div>

              <div className="flex items-center gap-3">
                <PhoneIcon className="h-5 w-5 text-gray-400" />
                <div>
                  <span className="text-sm font-medium text-gray-500">Phone</span>
                  <p className="text-gray-900">{currentUser.phone || 'Not provided'}</p>
                </div>
              </div>

              <div className="flex items-center gap-3">
                <MapPinIcon className="h-5 w-5 text-gray-400" />
                <div>
                  <span className="text-sm font-medium text-gray-500">ZIP Code</span>
                  <p className="text-gray-900">{currentUser.zip_code || 'Not provided'}</p>
                </div>
              </div>

            </div>

            {/* Quick Actions */}
            <div className="border-t pt-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h3>
              <div className="grid grid-cols-2 gap-4">
                <button
                  onClick={() => setCurrentPage('myBooks')}
                  className="p-4 bg-blue-50 rounded-lg text-center hover:bg-blue-100 transition-colors"
                >
                  <div className="text-2xl mb-2">📚</div>
                  <div className="font-medium text-blue-900">My Books</div>
                  <div className="text-sm text-blue-600">Manage your donated books</div>
                </button>
                
                <button
                  onClick={() => setCurrentPage('myRequests')}
                  className="p-4 bg-green-50 rounded-lg text-center hover:bg-green-100 transition-colors"
                >
                  <div className="text-2xl mb-2">🔍</div>
                  <div className="font-medium text-green-900">My Requests</div>
                  <div className="text-sm text-green-600">Track book requests</div>
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Image Cropper Modal */}
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
        onUseOriginal={handleUseOriginalWithProcessing}
        onClose={closeCropModal}
      />

      {/* Hidden canvas for cropping */}
      <canvas
        ref={canvasRef}
        style={{
          display: 'none',
        }}
      />
    </div>
  );
};

export default Profile;


