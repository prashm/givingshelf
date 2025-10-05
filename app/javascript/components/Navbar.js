import React from 'react';

const Navbar = ({ currentUser, setCurrentPage }) => {
  return (
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
                  {currentUser.first_name || 'Profile'}
                </li>
              </>
            ) : (
              <>
                <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('login')}>Login</li>
                <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('signup')}>Sign Up</li>
              </>
            )}
          </ul>
        </nav>
      </div>
    </header>
  );
};

export default Navbar; 