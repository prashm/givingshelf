import React, { useState, useEffect } from 'react';
import { ClockIcon, CheckIcon, XMarkIcon, EyeIcon } from '@heroicons/react/24/outline';

const MyRequests = ({ currentUser, setCurrentPage }) => {
  const [myRequests, setMyRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all'); // all, pending, approved, rejected

  useEffect(() => {
    // TODO: Fetch user's book requests from API
    // For now, using mock data
    const mockRequests = [
      {
        id: 1,
        book: {
          id: 1,
          title: 'The Great Gatsby',
          author: 'F. Scott Fitzgerald',
          cover_image_url: null
        },
        status: 'pending',
        requested_at: '2024-01-20',
        donor: {
          name: 'John Doe',
          email: 'john@example.com'
        }
      },
      {
        id: 2,
        book: {
          id: 2,
          title: 'To Kill a Mockingbird',
          author: 'Harper Lee',
          cover_image_url: null
        },
        status: 'approved',
        requested_at: '2024-01-15',
        approved_at: '2024-01-18',
        donor: {
          name: 'Jane Smith',
          email: 'jane@example.com'
        }
      },
      {
        id: 3,
        book: {
          id: 3,
          title: '1984',
          author: 'George Orwell',
          cover_image_url: null
        },
        status: 'rejected',
        requested_at: '2024-01-10',
        rejected_at: '2024-01-12',
        donor: {
          name: 'Bob Johnson',
          email: 'bob@example.com'
        },
        rejection_reason: 'Book already donated to someone else'
      }
    ];
    
    setTimeout(() => {
      setMyRequests(mockRequests);
      setLoading(false);
    }, 1000);
  }, []);

  const handleViewBook = (bookId) => {
    // TODO: Navigate to book detail page
    console.log('View book:', bookId);
  };

  const handleCancelRequest = (requestId) => {
    if (window.confirm('Are you sure you want to cancel this request?')) {
      // TODO: Cancel request via API
      setMyRequests(prev => prev.map(req => 
        req.id === requestId 
          ? { ...req, status: 'cancelled' }
          : req
      ));
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'pending':
        return 'bg-yellow-100 text-yellow-800';
      case 'approved':
        return 'bg-green-100 text-green-800';
      case 'rejected':
        return 'bg-red-100 text-red-800';
      case 'cancelled':
        return 'bg-gray-100 text-gray-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'pending':
        return <ClockIcon className="h-4 w-4" />;
      case 'approved':
        return <CheckIcon className="h-4 w-4" />;
      case 'rejected':
        return <XMarkIcon className="h-4 w-4" />;
      case 'cancelled':
        return <XMarkIcon className="h-4 w-4" />;
      default:
        return <ClockIcon className="h-4 w-4" />;
    }
  };

  const getStatusText = (status) => {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  };

  const filteredRequests = myRequests.filter(request => {
    if (filter === 'all') return true;
    return request.status === filter;
  });

  if (loading) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-6xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center justify-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            <span className="ml-2 text-gray-600">Loading your requests...</span>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto py-8 px-4 max-w-6xl">
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-3xl font-bold text-gray-900">My Book Requests</h2>
          <button
            onClick={() => setCurrentPage('home')}
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
          >
            Browse More Books
          </button>
        </div>

        {/* Filter Tabs */}
        <div className="border-b border-gray-200 mb-6">
          <nav className="-mb-px flex space-x-8">
            {[
              { key: 'all', label: 'All Requests', count: myRequests.length },
              { key: 'pending', label: 'Pending', count: myRequests.filter(r => r.status === 'pending').length },
              { key: 'approved', label: 'Approved', count: myRequests.filter(r => r.status === 'approved').length },
              { key: 'rejected', label: 'Rejected', count: myRequests.filter(r => r.status === 'rejected').length }
            ].map((tab) => (
              <button
                key={tab.key}
                onClick={() => setFilter(tab.key)}
                className={`py-2 px-1 border-b-2 font-medium text-sm ${
                  filter === tab.key
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                {tab.label}
                <span className="ml-2 bg-gray-100 text-gray-900 py-0.5 px-2.5 rounded-full text-xs">
                  {tab.count}
                </span>
              </button>
            ))}
          </nav>
        </div>

        {/* Requests List */}
        {filteredRequests.length === 0 ? (
          <div className="text-center py-12">
            <div className="text-6xl mb-4">📋</div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">No requests found</h3>
            <p className="text-gray-500 mb-6">
              {filter === 'all' 
                ? "You haven't made any book requests yet."
                : `You don't have any ${filter} requests.`
              }
            </p>
            {filter === 'all' && (
              <button
                onClick={() => setCurrentPage('home')}
                className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
              >
                Browse Books
              </button>
            )}
          </div>
        ) : (
          <div className="space-y-4">
            {filteredRequests.map((request) => (
              <div
                key={request.id}
                className="border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow"
              >
                <div className="flex items-start gap-4">
                  {/* Book Cover */}
                  <div className="w-20 h-24 bg-gray-100 rounded flex items-center justify-center flex-shrink-0">
                    {request.book.cover_image_url ? (
                      <img
                        src={request.book.cover_image_url}
                        alt={request.book.title}
                        className="w-full h-full object-cover rounded"
                      />
                    ) : (
                      <div className="text-gray-400 text-center">
                        <div className="text-2xl">📖</div>
                      </div>
                    )}
                  </div>

                  {/* Request Details */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-start justify-between mb-2">
                      <div>
                        <h3 className="font-semibold text-lg text-gray-900 mb-1">
                          {request.book.title}
                        </h3>
                        <p className="text-gray-600">by {request.book.author}</p>
                      </div>
                      
                      <div className="flex items-center gap-2">
                        <span className={`px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(request.status)}`}>
                          <div className="flex items-center gap-1">
                            {getStatusIcon(request.status)}
                            {getStatusText(request.status)}
                          </div>
                        </span>
                      </div>
                    </div>

                    {/* Donor Info */}
                    <div className="mb-3">
                      <p className="text-sm text-gray-600">
                        <span className="font-medium">Donor:</span> {request.donor.name}
                      </p>
                      <p className="text-sm text-gray-500">{request.donor.email}</p>
                    </div>

                    {/* Timestamps */}
                    <div className="text-sm text-gray-500 mb-3">
                      <p>Requested: {new Date(request.requested_at).toLocaleDateString()}</p>
                      {request.approved_at && (
                        <p>Approved: {new Date(request.approved_at).toLocaleDateString()}</p>
                      )}
                      {request.rejected_at && (
                        <p>Rejected: {new Date(request.rejected_at).toLocaleDateString()}</p>
                      )}
                    </div>

                    {/* Rejection Reason */}
                    {request.rejection_reason && (
                      <div className="mb-3 p-3 bg-red-50 border border-red-200 rounded-md">
                        <p className="text-sm text-red-700">
                          <span className="font-medium">Reason:</span> {request.rejection_reason}
                        </p>
                      </div>
                    )}

                    {/* Action Buttons */}
                    <div className="flex gap-2">
                      <button
                        onClick={() => handleViewBook(request.book.id)}
                        className="flex items-center gap-1 px-3 py-2 bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200 transition-colors"
                      >
                        <EyeIcon className="h-4 w-4" />
                        View Book
                      </button>
                      
                      {request.status === 'pending' && (
                        <button
                          onClick={() => handleCancelRequest(request.id)}
                          className="px-3 py-2 bg-red-100 text-red-700 rounded-md hover:bg-red-200 transition-colors"
                        >
                          Cancel Request
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Back Button */}
        <div className="mt-8 text-center">
          <button
            onClick={() => setCurrentPage('profile')}
            className="px-4 py-2 bg-gray-600 text-white rounded-md hover:bg-gray-700 transition-colors"
          >
            Back to Profile
          </button>
        </div>
      </div>
    </div>
  );
};

export default MyRequests;


