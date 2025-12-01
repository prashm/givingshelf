import React, { useEffect, useState } from 'react';
import { fetchBookRequestDetails } from '../../lib/bookRequestsApi';

const BookRequestDetail = ({ bookRequestId, setCurrentPage }) => {
  const [request, setRequest] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!bookRequestId) {
      setError('Missing book request id.');
      setLoading(false);
      return;
    }

    const loadDetails = async () => {
      setLoading(true);
      setError(null);
      try {
        const data = await fetchBookRequestDetails(bookRequestId);
        setRequest(data);
      } catch (err) {
        setError(err.response?.data?.error || 'Failed to load request details.');
      } finally {
        setLoading(false);
      }
    };

    loadDetails();
  }, [bookRequestId]);

  if (loading) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-3xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <p className="text-sm text-gray-500">Loading request details...</p>
        </div>
      </div>
    );
  }

  if (error || !request) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-3xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <p className="text-sm text-red-600 mb-4">
            {error || 'Unable to load this request.'}
          </p>
          <button
            type="button"
            onClick={() => setCurrentPage('messages')}
            className="px-4 py-2 text-sm rounded-md bg-emerald-600 text-white hover:bg-emerald-700"
          >
            Back to Messages
          </button>
        </div>
      </div>
    );
  }

  const createdAt = new Date(request.created_at).toLocaleString();

  return (
    <div className="container mx-auto py-8 px-4 max-w-3xl">
      <div className="bg-white rounded-lg shadow-md p-6 space-y-6">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-bold text-gray-900">Book Request Details</h2>
          <button
            type="button"
            onClick={() => setCurrentPage('messages')}
            className="text-sm text-emerald-700 hover:text-emerald-900"
          >
            Back to Messages
          </button>
        </div>

        <section>
          <h3 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-2">
            Book
          </h3>
          <div className="flex items-start justify-between">
            <div>
              <p className="text-lg font-medium text-gray-900">{request.book.title}</p>
              <p className="text-sm text-gray-600">by {request.book.author}</p>
              <button
                type="button"
                onClick={() =>
                  setCurrentPage('bookDetails', { selectedBook: request.book })
                }
                className="mt-2 text-sm text-emerald-700 hover:text-emerald-900 underline"
              >
                View book details
              </button>
            </div>
          </div>
        </section>

        <section>
          <h3 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-2">
            Requester
          </h3>
          <div className="space-y-1 text-sm text-gray-800">
            <p className="font-medium">{request.requester.name}</p>
            <p className="text-gray-600">{request.requester.location}</p>
          </div>
        </section>

        <section>
          <h3 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-2">
            Message
          </h3>
          <p className="text-sm text-gray-800 whitespace-pre-line">
            {request.message}
          </p>
        </section>

        <section className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm text-gray-700">
          <div>
            <p className="font-medium text-gray-500">Status</p>
            <p className="capitalize">{request.status}</p>
          </div>
          <div>
            <p className="font-medium text-gray-500">Requested at</p>
            <p>{createdAt}</p>
          </div>
        </section>
      </div>
    </div>
  );
};

export default BookRequestDetail;


