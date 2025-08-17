import React from 'react';
import { createRoot } from 'react-dom/client';
import App from '../components/App';
import '../styles/application.css';

document.addEventListener('DOMContentLoaded', () => {
  const container = document.getElementById('root');
  if (container) {
    const root = createRoot(container);
    root.render(<App />);
  }
}); 