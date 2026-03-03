import React, { useState, useEffect } from 'react';
import { fetchItemRequests } from '../../lib/itemRequestsApi';
import { parsePageFromPath } from '../../lib/textUtils';
import * as Constants from '../../lib/constants';

const MessagesPage = ({ setCurrentPage }) => {
  const [receivedRequests, setReceivedRequests] = useState([]);
  const [sentRequests, setSentRequests] = useState([]);
  const [loadingReceived, setLoadingReceived] = useState(false);
  const [loadingSent, setLoadingSent] = useState(false);
  const [errorReceived, setErrorReceived] = useState(null);
  const [errorSent, setErrorSent] = useState(null);

  const loadReceived = async () => {
    setLoadingReceived(true);
    setErrorReceived(null);
    try {
      const data = await fetchItemRequests('received');
      setReceivedRequests(data);
    } catch (err) {
      setErrorReceived(err.response?.data?.error || 'Failed to load requests received');
    } finally {
      setLoadingReceived(false);
    }
  };

  const loadSent = async () => {
    setLoadingSent(true);
    setErrorSent(null);
    try {
      const data = await fetchItemRequests('sent');
      setSentRequests(data);
    } catch (err) {
      setErrorSent(err.response?.data?.error || 'Failed to load requests sent');
    } finally {
      setLoadingSent(false);
    }
  };

  useEffect(() => {
    loadReceived();
  }, []);

  useEffect(() => {
    loadSent();
  }, []);

  const handleViewDetails = (requestId) => {
    setCurrentPage('itemRequestDetails', { itemRequestId: requestId });
  };

  const renderTable = (requests, type) => {
    if (requests.length === 0) {
      return (
        <p className="text-sm text-gray-500 text-center py-6">
          {type === 'received'
            ? 'No requests received for your items yet.'
            : 'You have not requested any items yet.'}
        </p>
      );
    }

    return (
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Item
              </th>
              {type === 'received' && (
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Requester
                </th>
              )}
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                {type === 'received' ? 'Received At' : 'Requested At'}
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
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
                      setCurrentPage('itemDetails', {
                        selectedBook: request.book || request.toy,
                        itemDetailSource: 'messages',
                        selectedItemType: request.book ? Constants.ITEM_TYPE_BOOK : Constants.ITEM_TYPE_TOY
                      })
                    }
                    className="text-emerald-700 hover:text-emerald-900 underline"
                  >
                    {(request.book || request.toy).title}
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
                <td className="px-4 py-3 text-sm text-gray-700">
                  {new Date(request.created_at).toLocaleString()}
                </td>
                <td className="px-4 py-3 text-sm text-gray-700">
                  {request.status_display || 'Pending'}
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
          <h2 className="text-2xl font-bold">My Item Requests</h2>
          <button
            onClick={() => {
              const path = typeof window !== 'undefined' ? window.location.pathname : '/';
              const parsed = parsePageFromPath(path);
              if (parsed.page === 'groupBrowse' && parsed.groupShortName && parsed.itemType) {
                setCurrentPage('groupBrowse', { groupShortName: parsed.groupShortName, itemType: parsed.itemType });
              } else if (parsed.page === 'groupLanding' && parsed.groupShortName) {
                setCurrentPage('groupLanding', { groupShortName: parsed.groupShortName });
              } else if (parsed.page === 'books') {
                setCurrentPage('books');
              } else if (parsed.page === 'toys') {
                setCurrentPage('toys');
              } else {
                setCurrentPage('home');
              }
            }}
            className="text-sm text-emerald-700 hover:text-emerald-900"
          >
            Back to Home
          </button>
        </div>

        <div className="overflow-y-auto max-h-[calc(100vh-12rem)] space-y-6">
          <section className="rounded-xl border border-gray-200 bg-white p-5 shadow-[0_4px_6px_-1px_rgba(0,0,0,0.08),0_2px_4px_-2px_rgba(0,0,0,0.06),0_0_0_1px_rgba(0,0,0,0.04)] ring-1 ring-black/5">
            <h3 className="text-lg font-semibold text-gray-900 mb-4 pb-2 border-b border-gray-100">Requests received</h3>
            {errorReceived && (
              <div className="mb-4 p-3 rounded-md bg-red-50 text-sm text-red-700">
                {errorReceived}
              </div>
            )}
            {loadingReceived ? (
              <p className="text-sm text-gray-500 py-6">Loading...</p>
            ) : (
              renderTable(receivedRequests, 'received')
            )}
          </section>
          <section className="rounded-xl border border-gray-200 bg-white p-5 shadow-[0_4px_6px_-1px_rgba(0,0,0,0.08),0_2px_4px_-2px_rgba(0,0,0,0.06),0_0_0_1px_rgba(0,0,0,0.04)] ring-1 ring-black/5">
            <h3 className="text-lg font-semibold text-gray-900 mb-4 pb-2 border-b border-gray-100">Requests sent</h3>
            {errorSent && (
              <div className="mb-4 p-3 rounded-md bg-red-50 text-sm text-red-700">
                {errorSent}
              </div>
            )}
            {loadingSent ? (
              <p className="text-sm text-gray-500 py-6">Loading...</p>
            ) : (
              renderTable(sentRequests, 'sent')
            )}
          </section>
        </div>
      </div>
    </div>
  );
};

export default MessagesPage;
