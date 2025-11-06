import React, { useState, useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { XMarkIcon, ArrowLeftIcon } from '@heroicons/react/24/outline';
import { useAuth } from '../../contexts/AuthContext';
import axios from '../../lib/axios';

const OtpVerification = ({ email, onBack, onSuccess }) => {
  const { checkAuthStatus } = useAuth();
  const [otpCode, setOtpCode] = useState(['', '', '', '', '', '']);
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isResending, setIsResending] = useState(false);
  const [resendCooldown, setResendCooldown] = useState(0);
  const [otpExpiry, setOtpExpiry] = useState(5 * 60); // 5 minutes in seconds
  const inputRefs = useRef([]);

  // Prevent body scroll when modal is open
  useEffect(() => {
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = '';
    };
  }, []);

  // OTP expiry countdown
  useEffect(() => {
    if (otpExpiry > 0) {
      const timer = setInterval(() => {
        setOtpExpiry(prev => {
          if (prev <= 1) {
            clearInterval(timer);
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
      return () => clearInterval(timer);
    }
  }, [otpExpiry]);

  // Resend cooldown countdown
  useEffect(() => {
    if (resendCooldown > 0) {
      const timer = setInterval(() => {
        setResendCooldown(prev => {
          if (prev <= 1) {
            clearInterval(timer);
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
      return () => clearInterval(timer);
    }
  }, [resendCooldown]);

  // Focus first input on mount
  useEffect(() => {
    if (inputRefs.current[0]) {
      inputRefs.current[0].focus();
    }
  }, []);

  const handleOtpChange = (index, value) => {
    // Only allow digits
    if (value && !/^\d$/.test(value)) {
      return;
    }

    const newOtpCode = [...otpCode];
    newOtpCode[index] = value;
    setOtpCode(newOtpCode);
    setError('');

    // Auto-focus next input
    if (value && index < 5) {
      inputRefs.current[index + 1]?.focus();
    }

    // Auto-submit when all 6 digits are entered
    if (value && index === 5 && newOtpCode.every(digit => digit !== '')) {
      handleSubmit(newOtpCode.join(''));
    }
  };

  const handleKeyDown = (index, e) => {
    // Handle backspace
    if (e.key === 'Backspace' && !otpCode[index] && index > 0) {
      inputRefs.current[index - 1]?.focus();
    }
    
    // Handle paste
    if (e.key === 'v' && (e.ctrlKey || e.metaKey)) {
      e.preventDefault();
      navigator.clipboard.readText().then(text => {
        const digits = text.replace(/\D/g, '').slice(0, 6).split('');
        if (digits.length === 6) {
          const newOtpCode = [...digits];
          setOtpCode(newOtpCode);
          inputRefs.current[5]?.focus();
          handleSubmit(newOtpCode.join(''));
        }
      });
    }
  };

  const handleSubmit = async (code = null) => {
    const otp = code || otpCode.join('');
    
    if (otp.length !== 6) {
      setError('Please enter a 6-digit code');
      return;
    }

    setIsLoading(true);
    setError('');

    try {
      const response = await axios.post('/api/verify_otp', {
        email: email,
        otp_code: otp
      }, {
        withCredentials: true
      });

      if (response.data.user) {
        // OTP verified successfully - refresh auth status to get current user
        await checkAuthStatus();
        const profileIncomplete = response.data.user.profile_complete === false;
        onSuccess(profileIncomplete);
      }
    } catch (err) {
      const errorMessage = err.response?.data?.error || 'Invalid verification code. Please try again.';
      setError(errorMessage);
      
      // Clear OTP on error
      setOtpCode(['', '', '', '', '', '']);
      inputRefs.current[0]?.focus();
    } finally {
      setIsLoading(false);
    }
  };

  const handleResendCode = async () => {
    if (resendCooldown > 0 || isResending) {
      return;
    }

    setIsResending(true);
    setError('');

    try {
      const response = await axios.post('/api/resend_otp', {
        email: email
      }, {
        withCredentials: true
      });

      if (response.data.message) {
        // Reset expiry and cooldown
        setOtpExpiry(5 * 60);
        setResendCooldown(20);
        setOtpCode(['', '', '', '', '', '']);
        inputRefs.current[0]?.focus();
        setError(''); // Clear any errors
      }
    } catch (err) {
      const errorMessage = err.response?.data?.error || 'Failed to resend code. Please try again.';
      setError(errorMessage);
      
      // Set cooldown if provided
      if (err.response?.data?.seconds_remaining) {
        setResendCooldown(err.response.data.seconds_remaining);
      }
    } finally {
      setIsResending(false);
    }
  };

  const formatTime = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const modalContent = (
    <div 
      className="fixed inset-0 z-[9999] flex items-center justify-center"
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        zIndex: 9999,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }}
    >
      {/* Backdrop */}
      <div 
        className="fixed inset-0 bg-black bg-opacity-50 backdrop-blur-sm"
        style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.5)',
          backdropFilter: 'blur(4px)',
          zIndex: 1
        }}
        onClick={onBack}
      />
      
      {/* Modal */}
      <div 
        className="relative rounded-lg shadow-xl w-full max-w-md mx-4"
        style={{
          position: 'relative',
          zIndex: 2,
          backgroundColor: '#ffffff',
          borderRadius: '0.5rem',
          boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)',
          width: '100%',
          maxWidth: '28rem',
          padding: '1.5rem',
          margin: '0 1rem'
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Close Button */}
        <button
          onClick={onBack}
          className="absolute top-4 right-4 text-gray-600 hover:text-gray-900 transition-colors"
        >
          <XMarkIcon className="h-6 w-6" />
        </button>

        {/* Back Button */}
        <button
          onClick={onBack}
          className="absolute top-4 left-4 text-gray-600 hover:text-gray-900 transition-colors"
        >
          <ArrowLeftIcon className="h-6 w-6" />
        </button>

        {/* Logo/Icon */}
        <div className="flex justify-center mb-6">
          <div className="w-12 h-12 bg-emerald-600 rounded-full flex items-center justify-center">
            <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
          </div>
        </div>

        {/* Title */}
        <h2 className="text-3xl font-bold text-gray-900 text-center mb-2">Enter Verification Code</h2>
        <p className="text-gray-600 text-center mb-2">
          We've sent a 6-digit code to
        </p>
        <p className="text-gray-900 text-center font-medium mb-8">
          {email}
        </p>

        {/* OTP Input */}
        <form onSubmit={(e) => { e.preventDefault(); handleSubmit(); }} className="space-y-6">
          <div 
            className="flex justify-center w-full"
            style={{
              gap: '0.25rem',
              padding: '0 0.75rem',
              maxWidth: '100%',
              boxSizing: 'border-box'
            }}
          >
            {otpCode.map((digit, index) => (
              <input
                key={index}
                ref={(el) => (inputRefs.current[index] = el)}
                type="text"
                inputMode="numeric"
                maxLength={1}
                value={digit}
                onChange={(e) => handleOtpChange(index, e.target.value)}
                onKeyDown={(e) => handleKeyDown(index, e)}
                className={`text-center text-base font-bold bg-transparent border-2 rounded-lg text-gray-900 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 ${
                  error ? 'border-red-500' : 'border-gray-300'
                }`}
                style={{
                  width: '2.25rem',
                  height: '2.5rem',
                  minWidth: '2.25rem',
                  maxWidth: '2.25rem',
                  flexShrink: 0,
                  boxSizing: 'border-box'
                }}
                disabled={isLoading || otpExpiry === 0}
              />
            ))}
          </div>

          {/* Error Message */}
          {error && (
            <p className="text-red-600 text-sm text-center font-medium">{error}</p>
          )}

          {/* Expiry Timer */}
          {otpExpiry > 0 ? (
            <p className="text-gray-600 text-sm text-center">
              Code expires in {formatTime(otpExpiry)}
            </p>
          ) : (
            <p className="text-red-600 text-sm text-center font-medium">
              Code has expired. Please request a new one.
            </p>
          )}

          {/* Resend Code */}
          <div className="text-center">
            <p className="text-gray-600 text-sm mb-2">
              Didn't receive the code?
            </p>
            {resendCooldown > 0 ? (
              <p className="text-gray-500 text-sm">
                Resend code in {resendCooldown}s
              </p>
            ) : (
              <button
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  if (!isResending && otpExpiry > 0) {
                    handleResendCode();
                  }
                }}
                disabled={isResending || otpExpiry === 0}
                className="text-emerald-600 hover:text-emerald-700 text-sm font-medium disabled:opacity-50 disabled:cursor-not-allowed transition-colors cursor-pointer"
              >
                {isResending ? 'Sending...' : 'Resend Code'}
              </button>
            )}
          </div>

          {/* Verify Button (fallback if auto-submit doesn't work) */}
          <button
            type="submit"
            disabled={isLoading || otpCode.some(digit => !digit) || otpExpiry === 0}
            className="w-full bg-emerald-600 hover:bg-emerald-700 text-white font-medium py-3 px-4 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isLoading ? 'Verifying...' : 'Verify Code'}
          </button>
        </form>
      </div>
    </div>
  );

  // Use portal if document is available
  if (typeof document !== 'undefined' && document.body) {
    return createPortal(modalContent, document.body);
  }
  
  return null;
};

export default OtpVerification;

