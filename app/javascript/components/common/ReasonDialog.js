import React, { useEffect, useState } from 'react';
import { XMarkIcon } from '@heroicons/react/24/outline';

const NOTE_MAX = 1000;

/**
 * Confirm step for a request status change, with an optional note that's shown under the change
 * in the request's thread. Cancelling the dialog changes nothing.
 * blockedMessage: when set, the action can't be taken right now; the dialog shows why, with no
 * note or confirm button.
 */
const ReasonDialog = ({
  open,
  title,
  description,
  noteLabel = 'Add a note (optional)',
  notePlaceholder = '',
  confirmLabel,
  busyLabel = 'Saving...',
  tone = 'danger',
  noteMax = NOTE_MAX,
  showNote = true,
  blockedMessage = '',
  busy = false,
  error = '',
  onConfirm,
  onClose
}) => {
  const [note, setNote] = useState('');

  useEffect(() => {
    if (open) setNote('');
  }, [open]);

  if (!open) return null;

  const confirmClass = tone === 'danger'
    ? 'bg-red-600 hover:bg-red-700'
    : 'bg-emerald-600 hover:bg-emerald-700';
  const close = () => { if (!busy) onClose(); };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 z-40 flex items-center justify-center px-4" role="dialog" aria-modal="true">
      <div className="bg-white rounded-lg shadow-xl max-w-lg w-full p-6 relative">
        <button type="button" onClick={close} className="absolute top-3 right-3 text-gray-400 hover:text-gray-600" aria-label="Close" disabled={busy}>
          <XMarkIcon className="h-6 w-6" />
        </button>
        <h2 className="text-xl font-semibold text-gray-900 mb-2">{title}</h2>
        {description && <p className="text-sm text-gray-600 mb-4">{description}</p>}
        {blockedMessage ? (
          <div className="space-y-4">
            <p className="p-3 bg-amber-50 border border-amber-200 rounded-md text-sm text-amber-800">{blockedMessage}</p>
            <div className="flex justify-end">
              <button type="button" onClick={close} className="px-4 py-2 text-sm rounded-md border border-gray-300 text-gray-700 hover:bg-gray-50">
                Close
              </button>
            </div>
          </div>
        ) : (
        <form
          onSubmit={(e) => { e.preventDefault(); if (!busy) onConfirm(note.trim()); }}
          className="space-y-4"
        >
          {showNote && (
          <div>
            <label htmlFor="reason-dialog-note" className="block text-sm font-medium text-gray-700 mb-1">{noteLabel}</label>
            <textarea
              id="reason-dialog-note"
              className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
              rows={3}
              maxLength={noteMax}
              value={note}
              placeholder={notePlaceholder}
              onChange={(e) => setNote(e.target.value)}
              disabled={busy}
            />
          </div>
          )}
          {error && <p className="text-sm text-red-600">{error}</p>}
          <div className="flex justify-end gap-3">
            <button type="button" onClick={close} className="px-4 py-2 text-sm rounded-md border border-gray-300 text-gray-700 hover:bg-gray-50" disabled={busy}>
              Go back
            </button>
            <button type="submit" className={`px-4 py-2 text-sm rounded-md text-white disabled:opacity-50 disabled:cursor-not-allowed ${confirmClass}`} disabled={busy}>
              {busy ? busyLabel : confirmLabel}
            </button>
          </div>
        </form>
        )}
      </div>
    </div>
  );
};

export default ReasonDialog;
