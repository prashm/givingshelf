import React from 'react';
import { ShieldCheckIcon } from '@heroicons/react/24/outline';

const VerificationBadge = ({ 
  trustScore, 
  size = 'md', 
  showTooltip = true,
  className = '',
  verified = true 
}) => {
  // Don't render if trust score is not available or if it's less than 70
  if (trustScore === undefined || trustScore === null || trustScore < 70) {
    return null;
  }

  // Don't render if verified is explicitly false (but allow undefined/null to default to true)
  if (verified === false) {
    return null;
  }

  const getTrustScoreIconColor = (score) => {
    if (score >= 70) return 'text-green-600';
    if (score >= 40) return 'text-yellow-600';
    return 'text-red-600';
  };

  const getSizeClasses = () => {
    switch (size) {
      case 'sm':
        return 'h-4 w-4';
      case 'md':
        return 'h-5 w-5';
      case 'lg':
        return 'h-8 w-8';
      default:
        return 'h-5 w-5';
    }
  };

  return (
    <div 
      className={`relative group inline-flex items-center ${className}`}
      title={showTooltip ? `Trust Score: ${trustScore}/100` : undefined}
    >
      <ShieldCheckIcon 
        className={`${getSizeClasses()} ${getTrustScoreIconColor(trustScore)}`}
      />
      {showTooltip && (
        <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-2 py-1 bg-gray-900 text-white text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap z-10">
          Trust Score: {trustScore}/100
        </div>
      )}
    </div>
  );
};

export default VerificationBadge;

