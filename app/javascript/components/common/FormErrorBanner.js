import React from 'react';
import { useScrollToError } from '../../hooks/useScrollToError';

// Drop-in error banner for any form save. When an error appears it scrolls itself
// into view and takes focus, so users don't have to manually scroll up to notice
// a failed save. Accessible by default (role="alert" + aria-live).
//
// Usage: <FormErrorBanner error={error} />
// `error` is typically a string, but any React node works. Pass `trigger` (an
// incrementing value) to force a re-scroll when the same error repeats.
const FormErrorBanner = ({
  error,
  trigger,
  className = 'bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-6',
}) => {
  const ref = useScrollToError(Boolean(error), { trigger });

  if (!error) return null;

  return (
    <div
      ref={ref}
      role="alert"
      aria-live="assertive"
      tabIndex={-1}
      className={`${className} focus:outline-none`}
    >
      {error}
    </div>
  );
};

export default FormErrorBanner;
