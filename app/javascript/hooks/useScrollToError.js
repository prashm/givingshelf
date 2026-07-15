import { useEffect, useRef } from 'react';

// Returns a ref to attach to an element (typically a form's error banner).
// Whenever `active` becomes truthy, the element is scrolled into view and focused
// so the user immediately sees the error even if they had scrolled away (e.g. a
// long form whose submit button sits well below a top-of-form error banner).
//
// `trigger` lets callers force a re-scroll even when the message text is
// unchanged (e.g. repeated failed submits that produce the identical error).
// Pass an incrementing value (such as a submit counter) to opt into that.
export function useScrollToError(active, { trigger, behavior = 'smooth', block = 'center' } = {}) {
  const ref = useRef(null);

  useEffect(() => {
    if (!active || !ref.current) return;

    ref.current.scrollIntoView({ behavior, block });
    if (typeof ref.current.focus === 'function') {
      ref.current.focus({ preventScroll: true });
    }
  }, [active, trigger, behavior, block]);

  return ref;
}

export default useScrollToError;
