import React, { useEffect } from 'react';
import { createPortal } from 'react-dom';
import { XMarkIcon } from '@heroicons/react/24/outline';

const WelcomeModal = ({ isOpen, onClose }) => {
  // Prevent body scroll when modal is open
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    return () => {
      document.body.style.overflow = '';
    };
  }, [isOpen]);

  if (!isOpen) return null;

  const modalContent = (
    <div
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        zIndex: 9999,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '1rem',
        pointerEvents: 'auto'
      }}
    >
      {/* Backdrop */}
      <div
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.5)',
          backdropFilter: 'blur(4px)',
          zIndex: 1
        }}
        onClick={onClose}
      />

      {/* Modal */}
      <div
        className="relative rounded-lg shadow-xl w-full max-w-lg p-8"
        style={{
          position: 'relative',
          zIndex: 2,
          backgroundColor: '#ffffff',
          borderRadius: '0.5rem',
          boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)',
          width: '100%',
          maxWidth: '32rem',
          padding: '2rem'
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Close Button */}
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-600 hover:text-gray-900 transition-colors"
        >
          <XMarkIcon className="h-6 w-6" />
        </button>

        {/* Logo/Icon */}
        <div className="flex justify-center mb-6">
          <img src="/bsc-icon.png" alt="GivingShelf Community" className="h-16 w-16" />
        </div>

        {/* Main Heading */}
        <h1 className="text-4xl font-bold text-gray-900 text-center mb-4">
          Welcome to GivingShelf Community
        </h1>

        {/* Tagline */}
        <p className="text-xl italic text-gray-600 text-center mb-8">
          A local, people-first way to pass stories forward.
        </p>

        {/* Location Permission Section */}
        <div className="bg-gray-50 rounded-lg p-6 mb-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-3">
            Why we ask for your location
          </h2>
          <p className="text-gray-700 text-sm leading-relaxed">
            Your browser may ask for location permission. We only use this information to help you find books in your local area. Your exact location is never stored or shared - we only use it to show you books nearby.
          </p>
        </div>

        {/* Get Started Button */}
        <button
          onClick={onClose}
          className="w-full text-white font-medium py-3 px-4 rounded-lg transition-colors hover:bg-emerald-700"
          style={{ backgroundColor: '#059669' }}
        >
          Get Started
        </button>
      </div>
    </div>
  );

  // Use portal if document is available
  if (typeof document !== 'undefined' && document.body) {
    return createPortal(modalContent, document.body);
  }

  return modalContent;
};

export default WelcomeModal;

