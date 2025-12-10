import React, { useEffect, useRef, useImperativeHandle, forwardRef } from 'react';

const TurnstileWidget = forwardRef(({ siteKey, onSuccess, onError, onExpire }, ref) => {
  const widgetIdRef = useRef(null);
  const containerRef = useRef(null);
  const scriptLoadedRef = useRef(false);

  useImperativeHandle(ref, () => ({
    reset: () => {
      if (window.turnstile && widgetIdRef.current !== null) {
        window.turnstile.reset(widgetIdRef.current);
      }
    },
    getResponse: () => {
      if (window.turnstile && widgetIdRef.current !== null) {
        return window.turnstile.getResponse(widgetIdRef.current);
      }
      return null;
    },
    remove: () => {
      if (window.turnstile && widgetIdRef.current !== null) {
        window.turnstile.remove(widgetIdRef.current);
        widgetIdRef.current = null;
      }
    }
  }));

  useEffect(() => {
    // Load Turnstile script if not already loaded
    if (!scriptLoadedRef.current) {
      const script = document.createElement('script');
      script.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js';
      script.async = true;
      script.defer = true;
      script.onload = () => {
        scriptLoadedRef.current = true;
        renderWidget();
      };
      script.onerror = () => {
        if (onError) {
          onError(new Error('Failed to load Cloudflare Turnstile'));
        }
      };
      document.head.appendChild(script);
    } else if (window.turnstile) {
      renderWidget();
    }

    return () => {
      // Cleanup on unmount
      if (window.turnstile && widgetIdRef.current !== null) {
        window.turnstile.remove(widgetIdRef.current);
      }
    };
  }, [siteKey]);

  const renderWidget = () => {
    if (!window.turnstile || !containerRef.current || widgetIdRef.current !== null) {
      return;
    }

    try {
      widgetIdRef.current = window.turnstile.render(containerRef.current, {
        sitekey: siteKey,
        callback: (token) => {
          if (onSuccess) {
            onSuccess(token);
          }
        },
        'error-callback': (error) => {
          if (onError) {
            onError(error);
          }
        },
        'expired-callback': () => {
          if (onExpire) {
            onExpire();
          }
        },
      });
    } catch (error) {
      if (onError) {
        onError(error);
      }
    }
  };

  return <div ref={containerRef} id="cf-turnstile-widget" />;
});

TurnstileWidget.displayName = 'TurnstileWidget';

export default TurnstileWidget;
