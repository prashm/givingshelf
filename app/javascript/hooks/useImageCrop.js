import { useState, useRef, useCallback } from 'react';
import { centerCrop, makeAspectCrop } from 'react-image-crop';

const ASPECT_RATIO = 1;
const MIN_DIMENSION = 150;

export const useImageCrop = () => {
  const imgRef = useRef(null);
  const canvasRef = useRef(null);
  const imageLoadedRef = useRef(false);
  
  const [showCropModal, setShowCropModal] = useState(false);
  const [originalImage, setOriginalImage] = useState(null);
  const [crop, setCrop] = useState();
  const [completedCrop, setCompletedCrop] = useState();
  const [croppedImage, setCroppedImage] = useState(null);

  // This is to demonstate how to make and center a % aspect crop
  // which is a bit trickier so we use some helper functions.
  function centerAspectCrop(
    mediaWidth,
    mediaHeight,
    aspect
  ) {
    return centerCrop(
      makeAspectCrop(
        {
          unit: '%',
          width: 90,
        },
        aspect,
        mediaWidth,
        mediaHeight,
      ),
      mediaWidth,
      mediaHeight,
    )
  }

  const onImageLoad = useCallback((e) => {
    const { width, height } = e.currentTarget;
    console.log('Image loaded:', width, height);
    
    // Only set initial crop if we haven't loaded this image yet
    if (!imageLoadedRef.current) {
      // Create a simple centered crop without aspect ratio
      const cropSize = Math.min(width, height) * 0.8; // 80% of smaller dimension
      const x = (width - cropSize) / 2;
      const y = (height - cropSize) / 2;
      
      const newCrop = {
        unit: 'px',
        x: x,
        y: y,
        width: cropSize,
        height: cropSize
      };
      console.log('Setting crop:', newCrop);
      setCrop(newCrop);
      imageLoadedRef.current = true;
    }
  }, []);

  const getCroppedImg = useCallback((image, crop, fileName) => {
    const canvas = canvasRef.current;
    if (!canvas || !image || !crop) {
      return null;
    }

    const scaleX = image.naturalWidth / image.width;
    const scaleY = image.naturalHeight / image.height;
    const ctx = canvas.getContext('2d');

    if (!ctx) {
      return null;
    }

    const pixelRatio = window.devicePixelRatio;
    canvas.width = crop.width * pixelRatio;
    canvas.height = crop.height * pixelRatio;

    ctx.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
    ctx.imageSmoothingQuality = 'high';

    ctx.drawImage(
      image,
      crop.x * scaleX,
      crop.y * scaleY,
      crop.width * scaleX,
      crop.height * scaleY,
      0,
      0,
      crop.width,
      crop.height
    );

    return new Promise((resolve) => {
      canvas.toBlob(
        (blob) => {
          if (!blob) {
            console.error('Canvas is empty');
            return;
          }
          blob.name = fileName;
          resolve(blob);
        },
        'image/jpeg',
        0.95
      );
    });
  }, []);

  const handleCropComplete = useCallback(async () => {
    if (!completedCrop || !imgRef.current) {
      return;
    }

    try {
      const croppedImageBlob = await getCroppedImg(
        imgRef.current,
        completedCrop,
        originalImage.name
      );

      if (croppedImageBlob) {
        setCroppedImage(croppedImageBlob);
        setShowCropModal(false);
        return croppedImageBlob;
      }
    } catch (error) {
      console.error('Error cropping image:', error);
    }
    return null;
  }, [completedCrop, originalImage, getCroppedImg]);

  const handleUseOriginal = useCallback(() => {
    setShowCropModal(false);
    return originalImage;
  }, [originalImage]);

  const openCropModal = useCallback((file) => {
    setOriginalImage(file);
    setShowCropModal(true);
    // Set a default crop that will be updated when image loads
    setCrop({
      unit: '%',
      x: 5,
      y: 5,
      width: 90,
      height: 90
    });
    setCompletedCrop(undefined);
    setCroppedImage(null);
    imageLoadedRef.current = false; // Reset the ref for new image
  }, []);

  const closeCropModal = useCallback(() => {
    setShowCropModal(false);
  }, []);

  const onCropChange = useCallback((newCrop) => {
    setCrop(newCrop);
  }, []);

  const onCropComplete = useCallback((newCrop) => {
    setCompletedCrop(newCrop);
  }, []);

  return {
    // Refs
    imgRef,
    canvasRef,
    
    // State
    showCropModal,
    originalImage,
    crop,
    completedCrop,
    croppedImage,
    
    // Actions
    onImageLoad,
    onCropChange,
    onCropComplete,
    handleCropComplete,
    handleUseOriginal,
    openCropModal,
    closeCropModal,
    setCrop,
    setCompletedCrop,
  };
};
