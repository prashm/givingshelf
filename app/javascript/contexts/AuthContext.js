import React, { createContext, useContext, useState, useEffect } from 'react';
import axios from 'axios';

const AuthContext = createContext();

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [currentUser, setCurrentUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    checkAuthStatus();
  }, []);

  const checkAuthStatus = async () => {
    try {
      const response = await axios.get('/api/users/profile', {
        withCredentials: true
      });
      setCurrentUser(response.data);
    } catch (error) {
      // This is expected for unauthenticated users
      setCurrentUser(null);
    } finally {
      setLoading(false);
    }
  };

  const login = async (email, password) => {
    try {
      const response = await axios.post('/api/login', {
        email: email,
        password: password
      }, {
        withCredentials: true
      });
      
      if (response.data.user) {
        setCurrentUser(response.data.user);
        return { success: true };
      }
    } catch (error) {
      throw new Error(error.response?.data?.error || 'Login failed');
    }
  };

  const register = async (userData) => {
    try {
      // Split name into first_name and last_name
      const nameParts = userData.name.split(' ');
      const firstName = nameParts[0] || '';
      const lastName = nameParts.slice(1).join(' ') || '';
      
      const response = await axios.post('/api/register', {
        user: {
          first_name: firstName,
          last_name: lastName,
          email_address: userData.email,
          zip_code: userData.zip_code,
          password: userData.password,
          password_confirmation: userData.password
        }
      }, {
        withCredentials: true
      });
      
      if (response.data.user) {
        setCurrentUser(response.data.user);
        return { success: true };
      }
    } catch (error) {
      throw new Error(error.response?.data?.error || 'Registration failed');
    }
  };

  const logout = async () => {
    try {
      await axios.delete('/api/logout', { withCredentials: true });
      setCurrentUser(null);
    } catch (error) {
      console.error('Logout error:', error);
    }
  };

  const updateProfile = async (userData) => {
    try {
      const response = await axios.patch(`/api/users/${currentUser.id}`, {
        user: userData
      }, {
        withCredentials: true
      });
      
      setCurrentUser(response.data);
      return { success: true };
    } catch (error) {
      return { 
        success: false, 
        error: error.response?.data?.errors?.join(', ') || 'Update failed' 
      };
    }
  };

  const value = {
    currentUser,
    loading,
    login,
    register,
    logout,
    updateProfile,
    checkAuthStatus
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}; 