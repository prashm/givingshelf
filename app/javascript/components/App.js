import React from 'react';
import { AuthProvider } from '../contexts/AuthContext';
import { BookProvider } from '../contexts/BookContext';
import BookDonationMarketplace from './BookDonationMarketplace';

const App = () => {
  return (
    <AuthProvider>
      <BookProvider>
        <BookDonationMarketplace />
      </BookProvider>
    </AuthProvider>
  );
};

export default App; 