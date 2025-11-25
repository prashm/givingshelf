import React, { useState } from 'react';
import { MapPinIcon, CalendarIcon, UserIcon, BookOpenIcon, ChevronLeftIcon, ChevronRightIcon, XMarkIcon } from '@heroicons/react/24/outline';

const BookDetail = ({ book, setCurrentPage, currentUser, onEditBook }) => {
  const [showContact, setShowContact] = useState(false);
  const [requestStatus, setRequestStatus] = useState('idle'); // idle, requesting, success, error
  const [currentImageIndex, setCurrentImageIndex] = useState(0);
  const [showImageModal, setShowImageModal] = useState(false);

  if (!book) {
    return (
      <div className="container mx-auto py-8 px-4 max-w-4xl">
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="text-center">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Book Not Found</h2>
            <p className="text-gray-600 mb-4">The book you're looking for doesn't exist.</p>
            <button
              onClick={() => setCurrentPage('home')}
              className="px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700"
            >
              Back to Home
            </button>
          </div>
        </div>
      </div>
    );
  }

  const handleRequestBook = async () => {
    if (!currentUser) {
      // TODO: Redirect to login
      setCurrentPage('login');
      return;
    }

    setRequestStatus('requesting');
    
    try {
      // TODO: Make API call to request book
      await new Promise(resolve => setTimeout(resolve, 1000)); // Simulate API call
      
      setRequestStatus('success');
      setShowContact(true);
    } catch (error) {
      setRequestStatus('error');
      console.error('Error requesting book:', error);
    }
  };

  const getConditionColor = (condition) => {
    switch (condition) {
      case 'excellent':
        return 'bg-green-100 text-green-800';
      case 'good':
        return 'bg-blue-100 text-blue-800';
      case 'fair':
        return 'bg-yellow-100 text-yellow-800';
      case 'poor':
        return 'bg-red-100 text-red-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  const getConditionDescription = (condition) => {
    switch (condition) {
      case 'excellent':
        return 'Like new, minimal wear';
      case 'good':
        return 'Light wear, still in good shape';
      case 'fair':
        return 'Moderate wear, readable condition';
      case 'poor':
        return 'Heavy wear, may have damage';
      default:
        return 'Unknown condition';
    }
  };

  return (
    <div className="container mx-auto py-8 px-4 max-w-4xl">
      <div className="bg-white rounded-lg shadow-md overflow-hidden">
        {/* Header with Back Button */}
        <div className="p-6 border-b border-gray-200">
          <button
            onClick={() => setCurrentPage('home')}
            className="flex items-center gap-2 text-blue-600 hover:text-blue-700 mb-4"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
            Back to search results
          </button>
          
          <h1 className="text-3xl font-bold text-gray-900">{book.title}</h1>
          <p className="text-xl text-gray-600">by {book.author}</p>
        </div>

        <div className="md:flex">
          {/* Left Column - Book Cover and Actions */}
          <div className="md:w-1/3 p-6">
            {/* Book Cover */}
            <div className="mb-6">
              {book.cover_image_url ? (
                <div className="mb-6">
                  <div className="flex justify-center">
                <img
                  src={book.cover_image_url}
                  alt={book.title}
                      className="w-16 h-20 sm:w-18 sm:h-24 md:w-20 md:h-28 object-cover rounded border shadow-sm"
                />
                  </div>
                </div>
              ) : (
                <div className="w-full h-80 bg-gray-100 rounded-lg flex items-center justify-center">
                  <div className="text-center text-gray-400">
                    <div className="text-6xl mb-2">📖</div>
                    <div className="text-lg">No Cover Available</div>
                  </div>
                </div>
              )}
            </div>

            {/* Action Buttons */}
            <div className="space-y-3">
              {currentUser ? (
                <>
                  {requestStatus === 'success' ? (
                    <div className="p-4 bg-green-50 border border-green-200 rounded-lg">
                      <div className="text-green-800 text-center">
                        <div className="text-lg font-medium mb-2">Request Sent!</div>
                        <p className="text-sm">The donor will contact you soon.</p>
                      </div>
                    </div>
                  ) : (
                    <button
                      onClick={handleRequestBook}
                      disabled={requestStatus === 'requesting'}
                      className="w-full bg-emerald-600 text-white py-3 px-4 rounded-lg hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                    >
                      {requestStatus === 'requesting' ? 'Sending Request...' : 'Request This Book'}
                    </button>
                  )}
                  
                  {requestStatus === 'error' && (
                    <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm text-center">
                      Failed to send request. Please try again.
                    </div>
                  )}
                </>
              ) : (
                <button
                  onClick={() => setCurrentPage('login')}
                  className="w-full bg-emerald-600 text-white py-3 px-4 rounded-lg hover:bg-emerald-700 transition-colors"
                >
                  Log in to Request
                </button>
              )}

              {onEditBook && book.user_id === currentUser?.id && (
                <button
                  onClick={() => onEditBook(book.id)}
                  className="w-full bg-emerald-600 text-white py-3 px-4 rounded-lg hover:bg-emerald-700 transition-colors mb-3"
                >
                  Edit This Book
                </button>
              )}
              
              <button
                onClick={() => setCurrentPage('donate')}
                className="w-full bg-green-600 text-white py-3 px-4 rounded-lg hover:bg-green-700 transition-colors"
              >
                Donate a Similar Book
              </button>
            </div>

            {/* Book Stats */}
            <div className="mt-6 p-4 bg-gray-50 rounded-lg">
              <h3 className="font-semibold text-gray-900 mb-3">Book Details</h3>
              <div className="space-y-2 text-sm">
                <div className="flex items-center gap-2">
                  <BookOpenIcon className="h-4 w-4 text-gray-400" />
                  <span className="text-gray-600">Genre:</span>
                  <span className="font-medium">{book.genre}</span>
                </div>
                <div className="flex items-center gap-2">
                  <CalendarIcon className="h-4 w-4 text-gray-400" />
                  <span className="text-gray-600">Published:</span>
                  <span className="font-medium">{book.published_year}</span>
                </div>
                {book.isbn && (
                  <div className="flex items-center gap-2">
                    <span className="text-gray-600">ISBN:</span>
                    <span className="font-medium font-mono">{book.isbn}</span>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Right Column - Book Information */}
          <div className="md:w-2/3 p-6">
            {/* Condition Badge */}
            <div className="mb-6">
              <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${getConditionColor(book.condition)}`}>
                {book.condition.charAt(0).toUpperCase() + book.condition.slice(1)} Condition
              </span>
              <p className="text-sm text-gray-600 mt-1">{getConditionDescription(book.condition)}</p>
            </div>

            {/* Summary */}
            {book.summary && (
              <div className="mb-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-2">Summary</h3>
                <p className="text-gray-700 leading-relaxed">{book.summary}</p>
              </div>
            )}

            {/* Additional Details */}
            <div className="mb-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-3">About This Book</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="flex items-center gap-3">
                  <UserIcon className="h-4 w-4 text-gray-400" />
                  <div>
                    <span className="text-sm font-medium text-gray-500">Donor</span>
                    <p className="text-gray-900">{book.donor_name || 'Anonymous'}</p>
                  </div>
                </div>
                
                <div className="flex items-center gap-3">
                  <MapPinIcon className="h-4 w-4 text-gray-400" />
                  <div>
                    <span className="text-sm font-medium text-gray-500">Location</span>
                    <p className="text-gray-900">{book.donor_zip_code || 'Not specified'}</p>
                  </div>
                </div>
                
                <div className="flex items-center gap-3">
                  <CalendarIcon className="h-4 w-4 text-gray-400" />
                  <div>
                    <span className="text-sm font-medium text-gray-500">Added</span>
                    <p className="text-gray-900">
                      {new Date(book.created_at).toLocaleDateString('en-US', {
                        year: 'numeric',
                        month: 'long',
                        day: 'numeric'
                      })}
                    </p>
                  </div>
                </div>
                
                <div className="flex items-center gap-3">
                  <BookOpenIcon className="h-4 w-4 text-gray-400" />
                  <div>
                    <span className="text-sm font-medium text-gray-500">Status</span>
                    <p className="text-gray-900 capitalize">{book.status || 'Available'}</p>
                  </div>
                </div>
              </div>
            </div>

            {/* Additional Photos Carousel */}
            {book.user_images_urls && book.user_images_urls.length > 0 && (
              <div className="mb-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-3">Additional Photos</h3>
                <div className="relative">
                  <div className="flex overflow-x-auto gap-2 pb-2 scrollbar-hide">
                    {book.user_images_urls.map((url, index) => (
                      <img
                        key={index}
                        src={url}
                        alt={`Book photo ${index + 1}`}
                        onClick={() => {
                          setCurrentImageIndex(index);
                          setShowImageModal(true);
                        }}
                        className="h-32 w-32 object-cover rounded-lg cursor-pointer hover:opacity-80 transition-opacity flex-shrink-0 border-2 border-gray-200"
                      />
                    ))}
                  </div>
                </div>
              </div>
            )}

            {/* Contact Information (shown after request) */}
            {showContact && book.donor_contact && (
              <div className="p-4 bg-blue-50 border border-blue-200 rounded-lg">
                <h3 className="font-semibold text-blue-900 mb-3">Contact Information</h3>
                <div className="space-y-2 text-sm">
                  <p><span className="font-medium">Name:</span> {book.donor_contact.name}</p>
                  <p><span className="font-medium">Email:</span> {book.donor_contact.email}</p>
                  {book.donor_contact.phone && (
                    <p><span className="font-medium">Phone:</span> {book.donor_contact.phone}</p>
                  )}
                </div>
                <p className="text-blue-700 text-sm mt-3">
                  The donor will contact you to arrange pickup or delivery.
                </p>
              </div>
            )}

            {/* Similar Books Suggestion */}
            <div className="mt-8 p-4 bg-gray-50 rounded-lg">
              <h3 className="font-semibold text-gray-900 mb-3">Looking for more?</h3>
              <p className="text-gray-600 mb-3">
                Discover similar books or explore other genres in your area.
              </p>
              <div className="flex gap-3">
                <button
                  onClick={() => setCurrentPage('home')}
                  className="px-4 py-2 bg-gray-600 text-white rounded-md hover:bg-gray-700 transition-colors"
                >
                  Browse More Books
                </button>
                <button
                  onClick={() => setCurrentPage('donate')}
                  className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition-colors"
                >
                  Donate a Book
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Image Modal/Carousel */}
      {showImageModal && book.user_images_urls && book.user_images_urls.length > 0 && (
        <div 
          className="fixed inset-0 bg-black bg-opacity-90 z-50 flex items-center justify-center p-4"
          onClick={() => setShowImageModal(false)}
        >
          <button
            onClick={(e) => {
              e.stopPropagation();
              setShowImageModal(false);
            }}
            className="absolute top-4 right-4 text-white hover:text-gray-300 z-10"
          >
            <XMarkIcon className="h-8 w-8" />
          </button>
          <button
            onClick={(e) => {
              e.stopPropagation();
              setCurrentImageIndex(prev => 
                prev > 0 ? prev - 1 : book.user_images_urls.length - 1
              );
            }}
            className="absolute left-4 text-white hover:text-gray-300 z-10"
          >
            <ChevronLeftIcon className="h-10 w-10" />
          </button>
          <img
            src={book.user_images_urls[currentImageIndex]}
            alt={`Book photo ${currentImageIndex + 1}`}
            className="max-w-full max-h-[90vh] object-contain"
            onClick={(e) => e.stopPropagation()}
          />
          <button
            onClick={(e) => {
              e.stopPropagation();
              setCurrentImageIndex(prev => 
                prev < book.user_images_urls.length - 1 ? prev + 1 : 0
              );
            }}
            className="absolute right-4 text-white hover:text-gray-300 z-10"
          >
            <ChevronRightIcon className="h-10 w-10" />
          </button>
          <div className="absolute bottom-4 text-white text-sm bg-black bg-opacity-50 px-3 py-1 rounded">
            {currentImageIndex + 1} / {book.user_images_urls.length}
          </div>
        </div>
      )}
    </div>
  );
};

export default BookDetail;
