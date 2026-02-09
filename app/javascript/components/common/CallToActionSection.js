import React from 'react';

const CallToActionSection = ({
  title = 'Ready to Share Your Books?',
  buttonText = 'Start Donating Today',
  currentUser,
  setCurrentPage,
  onOpenLoginModal,
  donateItemType = null,
  className = ''
}) => {
  const handleDonate = () => {
    const extraState = donateItemType ? { donateItemType } : {};
    if (currentUser) {
      setCurrentPage?.('donate', extraState);
    } else {
      onOpenLoginModal?.('donate', extraState);
    }
  };
  return (
    <div className={`text-center mt-12 ${className}`}>
      <h2 className="text-3xl font-bold mb-4">{title}</h2>
      <button
        type="button"
        onClick={handleDonate}
        className="bg-emerald-600 text-white px-8 py-3 rounded-md text-lg font-semibold hover:bg-emerald-700 transition-colors"
      >
        {buttonText}
      </button>
    </div>
  );
};

export default CallToActionSection;

