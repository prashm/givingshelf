import React from 'react';
import { AuthProvider } from '../contexts/AuthContext';
import BookDonationMarketplace from './BookDonationMarketplace';

const App = () => {
  return (
    <AuthProvider>
      <BookDonationMarketplace />
    </AuthProvider>
  );
};

export default App; 