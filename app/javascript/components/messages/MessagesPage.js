import React, { useState, useEffect } from 'react';
import { fetchBookRequests } from '../../lib/bookRequestsApi';

const MessagesPage = ({ setCurrentPage }) => {
  const [activeTab, setActiveTab] = useState('received');
  const [receivedRequests, setReceivedRequests] = useState([]);
  const [sentRequests, setSentRequests] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [hasLoadedReceived, setHasLoadedReceived] = useState(false);
  const [hasLoadedSent, setHasLoadedSent] = useState(false);

  const loadRequests = async (type) => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchBookRequests(type);
      if (type === 'received') {
        setReceivedRequests(data);
        setHasLoadedReceived(true);
      } else if (type === 'sent') {
        setSentRequests(data);
        setHasLoadedSent(true);
      }
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to load requests');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!hasLoadedReceived) {
      loadRequests('received');
    }
  }, [hasLoadedReceived]);

  const handleTabChange = (tab) => {
    setActiveTab(tab);
    if (tab === 'received' && !hasLoadedReceived) {
      loadRequests('received');
    } else if (tab === 'sent' && !hasLoadedSent) {
      loadRequests('sent');
    }
  };

  const handleViewDetails = (requestId) => {
    setCurrentPage('bookRequestDetails', { bookRequestId: requestId });
  };

  const renderTable = (requests, type) => {
    if (requests.length === 0) {
      return (
        <p className="text-sm text-gray-500 text-center py-6">
          {type === 'received'
            ? 'No requests received for your books yet.'
            : 'You have not requested any books yet.'}
        </p>
      );
    }

    return (
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Book
              </th>
              {type === 'received' && (
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Requester
                </th>
              )}
              {type === 'received' && (
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Message
                </th>
              )}
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                {type === 'received' ? 'Received At' : 'Requested At'}
              </th>
              <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {requests.map((request) => (
              <tr key={request.id}>
                <td className="px-4 py-3 text-sm text-gray-900">
                  <button
                    type="button"
                    onClick={() =>
                      setCurrentPage('bookDetails', { selectedBook: request.book })
                    }
                    className="text-emerald-700 hover:text-emerald-900 underline"
                  >
                    {request.book.title}
                  </button>
                </td>
                {type === 'received' && (
                  <td className="px-4 py-3 text-sm text-gray-700">
                    <div className="flex flex-col">
                      <span className="font-medium">{request.requester.name}</span>
                      <span className="text-xs text-gray-500">
                        {request.requester.location}
                      </span>
                    </div>
                  </td>
                )}
                {type === 'received' && (
                  <td className="px-4 py-3 text-sm text-gray-700 max-w-xs truncate">
                    {request.message}
                  </td>
                )}
                <td className="px-4 py-3 text-sm text-gray-700">
                  {new Date(request.created_at).toLocaleString()}
                </td>
                <td className="px-4 py-3 text-sm text-right">
                  <button
                    type="button"
                    onClick={() => handleViewDetails(request.id)}
                    className="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-md shadow-sm text-white bg-emerald-600 hover:bg-emerald-700"
                  >
                    Details
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  };

  return (
    <div className="container mx-auto py-8 px-4 max-w-5xl">
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-2xl font-bold">Messages</h2>
          <button
            onClick={() => setCurrentPage('home')}
            className="text-sm text-emerald-700 hover:text-emerald-900"
          >
            Back to Home
          </button>
        </div>

        <div className="border-b border-gray-200 mb-4">
          <nav className="-mb-px flex space-x-6" aria-label="Tabs">
            <button
              type="button"
              onClick={() => handleTabChange('received')}
              className={`whitespace-nowrap pb-2 px-1 border-b-2 text-sm font-medium ${
                activeTab === 'received'
                  ? 'border-emerald-500 text-emerald-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              Requests received
            </button>
            <button
              type="button"
              onClick={() => handleTabChange('sent')}
              className={`whitespace-nowrap pb-2 px-1 border-b-2 text-sm font-medium ${
                activeTab === 'sent'
                  ? 'border-emerald-500 text-emerald-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              Requests sent
            </button>
          </nav>
        </div>

        {error && (
          <div className="mb-4 p-3 rounded-md bg-red-50 text-sm text-red-700">
            {error}
          </div>
        )}

        {loading && (
          <p className="text-sm text-gray-500 mb-4">Loading...</p>
        )}

        {activeTab === 'received' && renderTable(receivedRequests, 'received')}
        {activeTab === 'sent' && renderTable(sentRequests, 'sent')}
      </div>
    </div>
  );
};

export default MessagesPage;

