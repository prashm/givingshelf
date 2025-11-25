import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { XMarkIcon } from '@heroicons/react/24/outline';
import axios from '../../lib/axios';
import OtpVerification from './OtpVerification';

const LoginSignupModal = ({ isOpen, onClose, onSuccess }) => {
  const [email, setEmail] = useState('');
  const [emailError, setEmailError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const [showOtpVerification, setShowOtpVerification] = useState(false);

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

  const validateEmail = (emailValue) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailValue.trim()) {
      return 'Email is required';
    }
    if (!emailRegex.test(emailValue)) {
      return 'Please enter a valid email address';
    }
    return '';
  };

  const handleEmailChange = (e) => {
    const value = e.target.value;
    setEmail(value);
    setEmailError('');
    setError('');
  };

  const handleContinue = async (e) => {
    e.preventDefault();
    
    const validationError = validateEmail(email);
    if (validationError) {
      setEmailError(validationError);
      return;
    }

    setIsLoading(true);
    setError('');

    try {
      const response = await axios.post('/api/login', {
        email: email.trim()
      }, {
        withCredentials: true
      });

      if (response.data.requires_otp) {
        // Show OTP verification page
        setShowOtpVerification(true);
      } else if (response.data.user) {
        // Old flow (shouldn't happen with 2FA enabled)
        onSuccess(false);
        onClose();
      }
    } catch (err) {
      setError(err.response?.data?.error || err.message || 'An error occurred. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleOtpSuccess = (profileIncomplete) => {
    onSuccess(profileIncomplete);
    onClose();
  };

  const handleBackFromOtp = () => {
    setShowOtpVerification(false);
    setError('');
  };

  // Reset state when modal closes
  useEffect(() => {
    if (!isOpen) {
      setShowOtpVerification(false);
      setError('');
      setEmail('');
      setEmailError('');
    }
  }, [isOpen]);

  if (!isOpen) return null;

  // If showing OTP verification, render it directly (it handles its own portal)
  if (showOtpVerification) {
    return (
      <OtpVerification
        email={email}
        onBack={handleBackFromOtp}
        onSuccess={handleOtpSuccess}
      />
    );
  }

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
        className="relative rounded-lg shadow-xl w-full max-w-md p-8"
        style={{ 
          position: 'relative', 
          zIndex: 2,
          backgroundColor: '#ffffff',
          borderRadius: '0.5rem',
          boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)',
          width: '100%',
          maxWidth: '28rem',
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
          <div className="w-12 h-12 bg-emerald-600 rounded-full flex items-center justify-center">
            <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
          </div>
        </div>

        {/* Title */}
        <h2 className="text-3xl font-bold text-gray-900 text-center mb-2">Sign In</h2>
        <p className="text-gray-600 text-center mb-8">
          Enter your email, and we'll send a code to your inbox. No need for passwords!
        </p>

        {/* Form */}
        <form onSubmit={handleContinue} className="space-y-6">
          {/* Email Input */}
          <div>
            <label htmlFor="email" className="block text-gray-900 text-sm font-medium mb-2">
              Email
            </label>
            <input
              type="email"
              id="email"
              value={email}
              onChange={handleEmailChange}
              className={`w-full px-4 py-3 bg-transparent border rounded-lg text-gray-900 placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-emerald-500 ${
                emailError ? 'border-red-500' : 'border-gray-300'
              }`}
              style={{ backgroundColor: 'transparent' }}
              placeholder="Enter your email address"
              disabled={isLoading}
            />
            {emailError && (
              <p className="mt-1 text-sm text-red-600">{emailError}</p>
            )}
          </div>

          {/* Error Message */}
          {error && (
            <div className="bg-red-50 border border-red-300 rounded-lg p-3">
              <p className="text-red-800 text-sm">{error}</p>
            </div>
          )}

          {/* Continue Button */}
          <button
            type="submit"
            disabled={isLoading}
            className="w-full text-white font-medium py-3 px-4 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed mt-5 hover:bg-emerald-700"
            style={{ marginTop: '1.25rem', backgroundColor: '#059669' }}
          >
            {isLoading ? 'Processing...' : 'Continue'}
          </button>
        </form>
      </div>
    </div>
  );

  // Use portal if document is available
  if (typeof document !== 'undefined' && document.body) {
    return createPortal(modalContent, document.body);
  }
  
  return modalContent;
};

export default LoginSignupModal;

