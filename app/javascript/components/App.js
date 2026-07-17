import React from 'react';
import { AuthProvider } from '../contexts/AuthContext';
import { SiteGroupProvider } from '../contexts/SiteGroupContext';
import AppShell from './AppShell';

const App = () => {
  return (
    <AuthProvider>
      <SiteGroupProvider>
        <AppShell />
      </SiteGroupProvider>
    </AuthProvider>
  );
};

export default App;
