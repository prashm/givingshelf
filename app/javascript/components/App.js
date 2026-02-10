import React from 'react';
import { AuthProvider } from '../contexts/AuthContext';
import AppShell from './AppShell';

const App = () => {
  return (
    <AuthProvider>
      <AppShell />
    </AuthProvider>
  );
};

export default App; 