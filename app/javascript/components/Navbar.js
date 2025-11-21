import React from 'react';
import LoginSignupModal from './auth/LoginSignupModal';

const Navbar = ({ currentUser, setCurrentPage, onLoginSuccess, onLogout, isLoginModalOpen, onOpenLoginModal, onCloseLoginModal }) => {
  const handleLoginClick = (e) => {
    e.preventDefault();
    e.stopPropagation();
    onOpenLoginModal();
  };

  const handleLoginSuccess = (profileIncomplete) => {
    onLoginSuccess(profileIncomplete);
  };

  return (
    <>
      <header className="bg-emerald-600 text-white p-4 shadow-sd">
        <div className="mx-auto flex justify-between items-center">
          <div className="flex items-center space-x-2 cursor-pointer" onClick={() => setCurrentPage('home')}>
            <img src="/bsc-icon.png" alt="BookShare Community" className="h-8 w-8" />
            <h1 className="text-2xl font-bold">BookShare Community</h1>
          </div>
          <nav>
            <ul className="flex space-x-6">
              <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('home')}>Browse</li>
              { currentUser ? ( 
                <>
                  <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('donate')}>Donate a Book</li>
                  <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('messages')}>Messages</li>
                  <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('profile')}>
                    {currentUser.first_name || currentUser.email_address || 'Profile'}
                  </li>
                  <li className="cursor-pointer hover:underline" onClick={onLogout}>Logout</li>
                </>
              ) : (
                <>
                  <li className="cursor-pointer hover:underline" onClick={handleLoginClick}>Login</li>
                </>
              )}
            </ul>
          </nav>
        </div>
      </header>
      {isLoginModalOpen && (
        <LoginSignupModal 
          isOpen={isLoginModalOpen}
          onClose={onCloseLoginModal}
          onSuccess={handleLoginSuccess}
        />
      )}
    </>
  );
};

export default Navbar; 