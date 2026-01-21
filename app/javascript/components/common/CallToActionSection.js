import React from 'react';

const CallToActionSection = ({
  title = 'Ready to Share Your Books?',
  buttonText = 'Start Donating Today',
  currentUser,
  setCurrentPage,
  onOpenLoginModal,
  className = ''
}) => {
  return (
    <div className={`text-center mt-12 ${className}`}>
      <h2 className="text-3xl font-bold mb-4">{title}</h2>
      <button
        type="button"
        onClick={() => {
          if (currentUser) {
            setCurrentPage?.('donate');
          } else {
            onOpenLoginModal?.('donate');
          }
        }}
        className="bg-emerald-600 text-white px-8 py-3 rounded-md text-lg font-semibold hover:bg-emerald-700 transition-colors"
      >
        {buttonText}
      </button>
    </div>
  );
};

export default CallToActionSection;

