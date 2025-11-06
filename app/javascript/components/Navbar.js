import React, { useState } from 'react';
import LoginSignupModal from './auth/LoginSignupModal';

const Navbar = ({ currentUser, setCurrentPage, onLoginSuccess, onLogout }) => {
  const [isModalOpen, setIsModalOpen] = useState(false);

  const handleLoginClick = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setIsModalOpen(true);
  };

  const handleModalClose = () => {
    setIsModalOpen(false);
  };

  const handleLoginSuccess = (profileIncomplete) => {
    onLoginSuccess(profileIncomplete);
    if (profileIncomplete) {
      setCurrentPage('profile');
    }
  };

  return (
    <>
      <header className="bg-emerald-600 text-white py-2 px-4 shadow-sm">
        <div className="container mx-auto flex justify-between items-center">
          <div className="flex items-center space-x-2 cursor-pointer" onClick={() => setCurrentPage('home')}>
            <img src="/bsc-icon.png" alt="BookShare Community" className="h-4 w-4" />
            <h1 className="text-lg font-semibold">BookShare Community</h1>
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
                  <li className="cursor-pointer hover:underline" onClick={handleLoginClick}>Sign Up</li>
                </>
              )}
            </ul>
          </nav>
        </div>
      </header>
      {isModalOpen && (
        <LoginSignupModal 
          isOpen={isModalOpen}
          onClose={handleModalClose}
          onSuccess={handleLoginSuccess}
        />
      )}
    </>
  );
};

export default Navbar; 