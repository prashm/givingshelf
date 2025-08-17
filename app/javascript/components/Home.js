import React, { useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useBooks } from '../contexts/BookContext';
import { useAuth } from '../contexts/AuthContext';
import { 
  HeartIcon, 
  MapPinIcon,
  MagnifyingGlassIcon 
} from '@heroicons/react/24/outline';

const Home = () => {
  const { currentUser } = useAuth();
  const { books, fetchBooks, loading } = useBooks();

  useEffect(() => {
    fetchBooks();
  }, []);

  // Ensure books is an array and get featured books
  const featuredBooks = Array.isArray(books) ? books.slice(0, 6) : [];

  return (
    <div className="space-y-12">
      {/* Hero Section */}
      <div className="bg-gradient-to-r from-green-600 to-green-800 text-white rounded-lg p-8 md:p-12">
        <div className="max-w-4xl mx-auto text-center">
          <h1 className="text-4xl md:text-6xl font-bold mb-6">
            Share Books, Build Community
          </h1>
          <p className="text-xl md:text-2xl mb-8 text-green-100">
            Donate your used books to neighbors in your local community. 
            Find great reads and connect with fellow book lovers.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            {currentUser ? (
              <Link
                to="/books/add"
                className="bg-white text-green-600 hover:bg-green-50 px-8 py-3 rounded-lg font-semibold text-lg transition-colors"
              >
                Donate a Book
              </Link>
            ) : (
              <Link
                to="/register"
                className="bg-white text-green-600 hover:bg-green-50 px-8 py-3 rounded-lg font-semibold text-lg transition-colors"
              >
                Get Started
              </Link>
            )}
            <Link
              to="/books"
              className="border-2 border-white text-white hover:bg-white hover:text-green-600 px-8 py-3 rounded-lg font-semibold text-lg transition-colors"
            >
              Browse Books
            </Link>
          </div>
        </div>
      </div>

      {/* Features Section */}
      <div className="grid md:grid-cols-3 gap-8">
        <div className="text-center p-6 bg-white rounded-lg shadow-md">
          <img src="/bsc-icon.png" alt="Donate Books" className="h-12 w-12 mx-auto mb-4" />
          <h3 className="text-xl font-semibold mb-2">Donate Books</h3>
          <p className="text-gray-600">
            Share your gently used books with your local community. 
            Give them a new life and help others discover great reads.
          </p>
        </div>
        
        <div className="text-center p-6 bg-white rounded-lg shadow-md">
          <MapPinIcon className="h-12 w-12 text-green-600 mx-auto mb-4" />
          <h3 className="text-xl font-semibold mb-2">Local Community</h3>
          <p className="text-gray-600">
            Connect with neighbors in your area. 
            Find books close to home and build meaningful connections.
          </p>
        </div>
        
        <div className="text-center p-6 bg-white rounded-lg shadow-md">
          <HeartIcon className="h-12 w-12 text-green-600 mx-auto mb-4" />
          <h3 className="text-xl font-semibold mb-2">Safe Exchange</h3>
          <p className="text-gray-600">
            Verified users and secure messaging ensure 
            safe and trustworthy book exchanges.
          </p>
        </div>
      </div>

      {/* Featured Books Section */}
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-2xl font-bold text-gray-900">Recent Books</h2>
          <Link
            to="/books"
            className="text-green-600 hover:text-green-700 font-medium"
          >
            View All →
          </Link>
        </div>

        {loading ? (
          <div className="text-center py-8">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-green-600 mx-auto"></div>
          </div>
        ) : featuredBooks.length > 0 ? (
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {featuredBooks.map((book) => (
              <div key={book.id} className="bg-gray-50 rounded-lg p-4 hover:shadow-md transition-shadow">
                <div className="flex items-start space-x-4">
                  {book.cover_image_url ? (
                    <img
                      src={book.cover_image_url}
                      alt={book.title}
                      className="w-16 h-20 object-cover rounded"
                    />
                  ) : (
                    <div className="w-16 h-20 bg-gray-300 rounded flex items-center justify-center">
                      <BookOpenIcon className="h-8 w-8 text-gray-500" />
                    </div>
                  )}
                  <div className="flex-1 min-w-0">
                    <h3 className="text-lg font-semibold text-gray-900 truncate">
                      {book.title}
                    </h3>
                    <p className="text-sm text-gray-600 mb-2">by {book.author}</p>
                    <div className="flex items-center text-sm text-gray-500 mb-2">
                      <MapPinIcon className="h-4 w-4 mr-1" />
                      {book.owner?.location || 'Location not available'}
                    </div>
                    <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                      book.condition === 'excellent' ? 'bg-green-100 text-green-800' :
                      book.condition === 'good' ? 'bg-blue-100 text-blue-800' :
                      book.condition === 'fair' ? 'bg-yellow-100 text-yellow-800' :
                      'bg-red-100 text-red-800'
                    }`}>
                      {book.condition}
                    </span>
                  </div>
                </div>
                <Link
                  to={`/books/${book.id}`}
                  className="mt-3 block text-green-600 hover:text-green-700 text-sm font-medium"
                >
                  View Details →
                </Link>
              </div>
            ))}
          </div>
        ) : (
          <div className="text-center py-8 text-gray-500">
            <BookOpenIcon className="h-12 w-12 mx-auto mb-4 text-gray-300" />
            <p>No books available yet. Be the first to donate!</p>
          </div>
        )}
      </div>

      {/* Call to Action */}
      {!currentUser && (
        <div className="bg-green-50 border border-green-200 rounded-lg p-8 text-center">
          <h2 className="text-2xl font-bold text-gray-900 mb-4">
            Join the BookShare Community
          </h2>
          <p className="text-gray-600 mb-6">
            Create an account to start donating and requesting books in your local area.
          </p>
          <Link
            to="/register"
            className="bg-green-600 hover:bg-green-700 text-white px-8 py-3 rounded-lg font-semibold transition-colors"
          >
            Sign Up Now
          </Link>
        </div>
      )}
    </div>
  );
};

export default Home; 