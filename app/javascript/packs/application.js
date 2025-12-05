import React from 'react';
import { createRoot } from 'react-dom/client';
import * as Sentry from '@sentry/react';
import App from '../components/App';
import '../styles/application.css';

// Initialize Sentry before React renders
const sentryDsnMeta = document.querySelector('meta[name="sentry-dsn"]');
const sentryDsn = sentryDsnMeta ? sentryDsnMeta.getAttribute('content') : null;

if (sentryDsn) {
  const environmentMeta = document.querySelector('meta[name="sentry-environment"]');
  const releaseMeta = document.querySelector('meta[name="sentry-release"]');
  
  Sentry.init({
    dsn: sentryDsn,
    integrations: [
      Sentry.browserTracingIntegration(),
      Sentry.replayIntegration({
        maskAllText: true,
        blockAllMedia: true,
      }),
    ],
    // Performance Monitoring
    tracesSampleRate: 0.1,
    // Session Replay
    replaysSessionSampleRate: 0.1,
    replaysOnErrorSampleRate: 1.0,
    // Set environment
    environment: environmentMeta ? environmentMeta.getAttribute('content') : 'development',
    // Set release version if available
    release: releaseMeta ? releaseMeta.getAttribute('content') : undefined,
  });
}

document.addEventListener('DOMContentLoaded', () => {
  const container = document.getElementById('root');
  if (container) {
    const root = createRoot(container);
    root.render(
      <Sentry.ErrorBoundary fallback={({ error, resetError }) => (
        <div style={{ padding: '20px', textAlign: 'center' }}>
          <h2>Something went wrong</h2>
          <p>{error.toString()}</p>
          <button onClick={resetError}>Try again</button>
        </div>
      )}>
        <App />
      </Sentry.ErrorBoundary>
    );
  }
}); 