import React, { useState, useEffect } from 'react';
import { useBooks } from '../contexts/BookContext';
import { useAuth } from '../contexts/AuthContext';
import { 
  MagnifyingGlassIcon, 
  ArrowUpTrayIcon, 
  UserIcon, 
  ChatBubbleLeftRightIcon, 
  MapPinIcon, 
  ShieldCheckIcon 
} from '@heroicons/react/24/outline';

// Main App Component
const BookDonationMarketplace = () => {
  const { currentUser } = useAuth();
  const { books, fetchBooks, loading } = useBooks();
  const [currentPage, setCurrentPage] = useState('home');
  const [searchResults, setSearchResults] = useState([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [zipCode, setZipCode] = useState('');
  const [selectedBook, setSelectedBook] = useState(null);
  
  // Load books on mount
  useEffect(() => {
    fetchBooks();
  }, []);

  // Update search results when books change
  useEffect(() => {
    if (Array.isArray(books)) {
      setSearchResults(books);
    }
  }, [books]);
  
  const handleSearch = () => {
    // Filter books based on search query (title or author)
    const query = searchQuery.toLowerCase();
    const results = Array.isArray(books) ? books.filter(book => 
      book.title.toLowerCase().includes(query) || 
      book.author.toLowerCase().includes(query)
    ) : [];
    
    setSearchResults(results);
  };
  
  const handleBookSelect = (book) => {
    setSelectedBook(book);
    if (!currentUser) {
      setCurrentPage('login');
    } else {
      setCurrentPage('bookDetails');
    }
  };
  
  const handleDonateBook = (bookData) => {
    // This will be handled by the BookContext
    setCurrentPage('home');
  };
  
  const renderPage = () => {
    switch(currentPage) {
      case 'home':
        return <HomePage 
          books={searchResults} 
          searchQuery={searchQuery}
          setSearchQuery={setSearchQuery}
          zipCode={zipCode}
          setZipCode={setZipCode}
          handleSearch={handleSearch}
          handleBookSelect={handleBookSelect}
          currentUser={currentUser}
          setCurrentPage={setCurrentPage}
        />;
      case 'login':
        return <LoginPage 
          setCurrentPage={setCurrentPage}
        />;
      case 'signup':
        return <SignupPage 
          setCurrentPage={setCurrentPage}
        />;
      case 'donate':
        return <DonatePage 
          handleDonateBook={handleDonateBook} 
          setCurrentPage={setCurrentPage}
        />;
      case 'bookDetails':
        return <BookDetailsPage 
          book={selectedBook} 
          setCurrentPage={setCurrentPage}
          currentUser={currentUser}
        />;
      case 'messages':
        return <MessagesPage 
          setCurrentPage={setCurrentPage}
          currentUser={currentUser}
        />;
      case 'profile':
        return <ProfilePage 
          currentUser={currentUser} 
          setCurrentPage={setCurrentPage}
        />;
      default:
        return <HomePage 
          books={searchResults} 
          searchQuery={searchQuery}
          setSearchQuery={setSearchQuery}
          zipCode={zipCode}
          setZipCode={setZipCode}
          handleSearch={handleSearch}
          handleBookSelect={handleBookSelect}
          currentUser={currentUser}
          setCurrentPage={setCurrentPage}
        />;
    }
  };
  
  return (
    <div className="flex flex-col min-h-screen">
      <Header 
        currentUser={currentUser} 
        setCurrentPage={setCurrentPage} 
      />
      <main className="flex-grow bg-gray-50">
        {renderPage()}
      </main>
      <Footer />
    </div>
  );
};

// Header Component
const Header = ({ currentUser, setCurrentPage }) => {
  return (
    <header className="bg-emerald-600 text-white py-2 px-4 shadow-sm">
      <div className="container mx-auto flex justify-between items-center">
        <div className="flex items-center space-x-2 cursor-pointer" onClick={() => setCurrentPage('home')}>
          <img src="/bsc-icon.png" alt="BookShare Community" className="h-4 w-4" />
          <h1 className="text-lg font-semibold">BookShare Community</h1>
        </div>
        <nav>
          <ul className="flex space-x-6">
            <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('home')}>Browse</li>
            {currentUser ? (
              <>
                <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('donate')}>Donate a Book</li>
                <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('messages')}>Messages</li>
                <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('profile')}>
                  {currentUser.first_name || 'Profile'}
                </li>
              </>
            ) : (
              <>
                <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('login')}>Login</li>
                <li className="cursor-pointer hover:underline" onClick={() => setCurrentPage('signup')}>Sign Up</li>
              </>
            )}
          </ul>
        </nav>
      </div>
    </header>
  );
};

// HomePage Component
const HomePage = ({ 
  books, 
  searchQuery, 
  setSearchQuery, 
  zipCode, 
  setZipCode, 
  handleSearch, 
  handleBookSelect,
  currentUser,
  setCurrentPage
}) => {
  return (
    <div className="container mx-auto py-8 px-4">
      <div className="bg-white rounded-lg shadow-md p-6 mb-8">
        <h2 className="text-3xl font-bold text-center mb-6">Find Books in Your Community</h2>
        <div className="flex flex-col md:flex-row gap-4 mb-6">
          <div className="flex-grow">
            <label className="block text-gray-700 mb-2">Book Title or Author</label>
            <div className="relative">
              <input 
                type="text" 
                className="w-full border rounded-md p-3"
                placeholder="Search by title or author..." 
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
              <MagnifyingGlassIcon className="absolute right-3 top-3 h-5 w-5 text-gray-400 pointer-events-none" width={20} height={20} />
            </div>
          </div>
          <div className="md:w-1/4">
            <label className="block text-gray-700 mb-2">Your ZIP Code</label>
            <input 
              type="text" 
              className="w-full border rounded-md p-3"
              placeholder="Enter ZIP code" 
              value={zipCode}
              onChange={(e) => setZipCode(e.target.value)}
            />
          </div>
          <div className="md:w-1/6 flex items-end">
            <button 
              className="w-full bg-emerald-600 text-white py-3 px-4 rounded-md hover:bg-emerald-700"
              onClick={handleSearch}
            >
              Search
            </button>
          </div>
        </div>
        
        {!currentUser && (
          <div className="bg-blue-50 border border-blue-200 rounded-md p-4 mb-6">
            <p className="text-center text-blue-800">
              <strong>Want to donate books?</strong> <span 
                className="underline cursor-pointer" 
                onClick={() => setCurrentPage('signup')}
              >
                Create an account
              </span> to share your books with the community.
            </p>
          </div>
        )}
      </div>
      
      <div className="mb-6">
        <h3 className="text-2xl font-semibold mb-4">Available Books</h3>
        {!Array.isArray(books) || books.length === 0 ? (
          <div className="text-center py-8 bg-gray-100 rounded-md">
            <p className="text-gray-600">No books matching your search criteria.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            {books.map(book => (
              <BookCard 
                key={book.id} 
                book={book} 
                onClick={() => handleBookSelect(book)} 
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

// BookCard Component
const BookCard = ({ book, onClick }) => {
  return (
    <div 
      className="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow cursor-pointer"
      onClick={onClick}
    >
      <div className="h-64 overflow-hidden flex justify-center bg-gray-100">
        {book.cover_image_url ? (
          <img 
            src={book.cover_image_url} 
            alt={book.title} 
            className="object-cover w-full h-full"
          />
        ) : (
          <div className="flex items-center justify-center h-full">
            <img src="/bsc-icon.png" alt="BookShare Community" className="h-16 w-16" />
          </div>
        )}
      </div>
      <div className="p-4">
        <h3 className="text-lg font-semibold mb-1 truncate">{book.title}</h3>
        <p className="text-gray-600 mb-2">{book.author}</p>
        <p className="text-sm text-gray-500 mb-3">Condition: {book.condition}</p>
        <div className="flex justify-between items-center">
          <div className="flex items-center text-sm text-gray-500">
            <MapPinIcon className="h-4 w-4 mr-1" />
            <span>{book.owner?.location || 'Location not available'}</span>
          </div>
          <button className="bg-emerald-100 hover:bg-emerald-200 text-emerald-800 px-3 py-1 rounded-md text-sm">
            Details
          </button>
        </div>
      </div>
    </div>
  );
};

// LoginPage Component
const LoginPage = ({ setCurrentPage }) => {
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  
  const submitLogin = async (e) => {
    e.preventDefault();
    setError('');
    
    try {
      await login(email, password);
      setCurrentPage('home');
    } catch (err) {
      setError(err.message || 'Login failed');
    }
  };
  
  return (
    <div className="container mx-auto py-12 px-4 max-w-md">
      <div className="bg-white rounded-lg shadow-md p-8">
        <h2 className="text-2xl font-bold mb-6 text-center">Log In</h2>
        {error && (
          <div className="mb-4 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
            {error}
          </div>
        )}
        <form onSubmit={submitLogin}>
          <div className="mb-4">
            <label className="block text-gray-700 mb-2">Email</label>
            <input 
              type="email" 
              className="w-full border rounded-md p-3"
              placeholder="Enter your email" 
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>
          <div className="mb-6">
            <label className="block text-gray-700 mb-2">Password</label>
            <input 
              type="password" 
              className="w-full border rounded-md p-3"
              placeholder="Enter your password" 
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>
          <button 
            type="submit" 
            className="w-full bg-emerald-600 text-white py-3 px-4 rounded-md hover:bg-emerald-700"
          >
            Log In
          </button>
        </form>
        <div className="mt-4 text-center">
          <p className="text-gray-600">
            Don't have an account? <span 
              className="text-emerald-600 cursor-pointer hover:underline"
              onClick={() => setCurrentPage('signup')}
            >
              Sign up
            </span>
          </p>
        </div>
      </div>
    </div>
  );
};

// SignupPage Component
const SignupPage = ({ setCurrentPage }) => {
  const { register } = useAuth();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [zipCode, setZipCode] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  
  const submitSignup = async (e) => {
    e.preventDefault();
    setError('');
    
    try {
      await register({ name, email, zip_code: zipCode, password });
      setCurrentPage('home');
    } catch (err) {
      setError(err.message || 'Registration failed');
    }
  };
  
  return (
    <div className="container mx-auto py-12 px-4 max-w-md">
      <div className="bg-white rounded-lg shadow-md p-8">
        <h2 className="text-2xl font-bold mb-6 text-center">Create an Account</h2>
        <div className="mb-4 rounded-md bg-blue-50 border border-blue-200 p-4">
          <div className="flex items-start">
            <ShieldCheckIcon className="text-blue-500 mr-3 mt-1 h-5 w-5" />
            <p className="text-sm text-blue-800">
              We verify all users to ensure a safe community marketplace. Your information is kept private and secure.
            </p>
          </div>
        </div>
        {error && (
          <div className="mb-4 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
            {error}
          </div>
        )}
        <form onSubmit={submitSignup}>
          <div className="mb-4">
            <label className="block text-gray-700 mb-2">Full Name</label>
            <input 
              type="text" 
              className="w-full border rounded-md p-3"
              placeholder="Enter your full name" 
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
            />
          </div>
          <div className="mb-4">
            <label className="block text-gray-700 mb-2">Email</label>
            <input 
              type="email" 
              className="w-full border rounded-md p-3"
              placeholder="Enter your email" 
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>
          <div className="mb-4">
            <label className="block text-gray-700 mb-2">ZIP Code</label>
            <input 
              type="text" 
              className="w-full border rounded-md p-3"
              placeholder="Enter your ZIP code" 
              value={zipCode}
              onChange={(e) => setZipCode(e.target.value)}
              required
            />
          </div>
          <div className="mb-6">
            <label className="block text-gray-700 mb-2">Password</label>
            <input 
              type="password" 
              className="w-full border rounded-md p-3"
              placeholder="Create a password" 
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>
          <button 
            type="submit" 
            className="w-full bg-emerald-600 text-white py-3 px-4 rounded-md hover:bg-emerald-700"
          >
            Create Account
          </button>
        </form>
        <div className="mt-4 text-center">
          <p className="text-gray-600">
            Already have an account? <span 
              className="text-emerald-600 cursor-pointer hover:underline"
              onClick={() => setCurrentPage('login')}
            >
              Log in
            </span>
          </p>
        </div>
      </div>
    </div>
  );
};

// DonatePage Component
const DonatePage = ({ handleDonateBook, setCurrentPage }) => {
  const { createBook } = useBooks();
  const [title, setTitle] = useState('');
  const [author, setAuthor] = useState('');
  const [condition, setCondition] = useState('good');
  const [description, setDescription] = useState('');
  const [image, setImage] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  
  const submitDonation = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    
    try {
      const bookData = {
        title,
        author,
        condition,
        summary: description,
        cover_image: image
      };
      
      const result = await createBook(bookData);
      if (result.success) {
        handleDonateBook(result.book);
      } else {
        setError(result.error);
      }
    } catch (err) {
      setError('Failed to create book');
    } finally {
      setLoading(false);
    }
  };
  
  return (
    <div className="container mx-auto py-8 px-4 max-w-2xl">
      <div className="bg-white rounded-lg shadow-md p-8">
        <h2 className="text-2xl font-bold mb-6">Donate a Book</h2>
        {error && (
          <div className="mb-4 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
            {error}
          </div>
        )}
        <form onSubmit={submitDonation}>
          <div className="mb-6">
            <div className="flex items-center justify-center bg-gray-100 border-2 border-dashed border-gray-300 rounded-lg h-64 mb-4">
              {image ? (
                <img src={URL.createObjectURL(image)} alt="Book cover" className="h-full object-contain" />
              ) : (
                <div className="text-center">
                  <ArrowUpTrayIcon className="mx-auto text-gray-400 mb-2 h-9 w-9" />
                  <p className="text-gray-500">Upload book cover image</p>
                </div>
              )}
            </div>
            <input 
              type="file"
              id="cover-image"
              className="w-full"
              accept="image/*"
              onChange={(e) => setImage(e.target.files[0])}
            />
          </div>
          
          <div className="mb-4">
            <label className="block text-gray-700 mb-2">Book Title*</label>
            <input 
              type="text" 
              className="w-full border rounded-md p-3"
              placeholder="Enter book title" 
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              required
            />
          </div>
          
          <div className="mb-4">
            <label className="block text-gray-700 mb-2">Author*</label>
            <input 
              type="text" 
              className="w-full border rounded-md p-3"
              placeholder="Enter author name" 
              value={author}
              onChange={(e) => setAuthor(e.target.value)}
              required
            />
          </div>
          
          <div className="mb-4">
            <label className="block text-gray-700 mb-2">Condition*</label>
            <select 
              className="w-full border rounded-md p-3"
              value={condition}
              onChange={(e) => setCondition(e.target.value)}
              required
            >
              <option value="excellent">Excellent</option>
              <option value="good">Good</option>
              <option value="fair">Fair</option>
              <option value="poor">Poor</option>
            </select>
          </div>
          
          <div className="mb-6">
            <label className="block text-gray-700 mb-2">Description</label>
            <textarea 
              className="w-full border rounded-md p-3 h-32"
              placeholder="Provide a brief description of the book and its current condition..." 
              value={description}
              onChange={(e) => setDescription(e.target.value)}
            ></textarea>
          </div>
          
          <div className="flex gap-4">
            <button 
              type="button" 
              className="flex-1 bg-gray-200 text-gray-800 py-3 px-4 rounded-md hover:bg-gray-300"
              onClick={() => setCurrentPage('home')}
            >
              Cancel
            </button>
            <button 
              type="submit" 
              className="flex-1 bg-emerald-600 text-white py-3 px-4 rounded-md hover:bg-emerald-700 disabled:opacity-50"
              disabled={loading}
            >
              {loading ? 'Creating...' : 'Donate Book'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

// BookDetailsPage Component
const BookDetailsPage = ({ book, setCurrentPage, currentUser }) => {
  const [showContact, setShowContact] = useState(false);
  
  if (!book) {
    return (
      <div className="container mx-auto py-8 px-4">
        <div className="text-center">
          <p>Book not found</p>
          <button 
            className="mt-4 text-emerald-600 hover:underline"
            onClick={() => setCurrentPage('home')}
          >
            Back to search results
          </button>
        </div>
      </div>
    );
  }
  
  return (
    <div className="container mx-auto py-8 px-4">
      <button 
        className="mb-4 flex items-center text-emerald-600 hover:underline"
        onClick={() => setCurrentPage('home')}
      >
        <svg className="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 19l-7-7 7-7"></path>
        </svg>
        Back to search results
      </button>
      
      <div className="bg-white rounded-lg shadow-md p-6 md:p-8">
        <div className="flex flex-col md:flex-row gap-8">
          <div className="md:w-1/3 lg:w-1/4">
            <div className="bg-gray-100 rounded-md overflow-hidden">
              {book.cover_image_url ? (
                <img 
                  src={book.cover_image_url} 
                  alt={book.title} 
                  className="w-full object-cover"
                />
              ) : (
                <div className="flex items-center justify-center h-64">
                  <img src="/bsc-icon.png" alt="BookShare Community" className="h-16 w-16" />
                </div>
              )}
            </div>
          </div>
          
          <div className="md:w-2/3 lg:w-3/4">
            <h1 className="text-3xl font-bold mb-2">{book.title}</h1>
            <p className="text-xl text-gray-600 mb-4">by {book.author}</p>
            
            <div className="mb-6">
              <div className="flex items-center mb-2">
                <UserIcon className="h-5 w-5 text-gray-500 mr-2" />
                <span className="text-gray-700">Donated by {book.owner?.full_name || 'Unknown'}</span>
              </div>
              <div className="flex items-center mb-2">
                <MapPinIcon className="h-5 w-5 text-gray-500 mr-2" />
                <span className="text-gray-700">{book.owner?.location || 'Location not available'}</span>
              </div>
            </div>
            
            <div className="mb-6">
              <h3 className="text-lg font-semibold mb-2">Description</h3>
              <p className="text-gray-700 mb-4">{book.summary || 'No description available'}</p>
              <div className="bg-gray-50 border border-gray-200 rounded-md p-3">
                <h4 className="font-medium mb-1">Condition</h4>
                <p className="text-gray-700">{book.condition}</p>
              </div>
            </div>
            
            {!showContact ? (
              <button 
                className="w-full md:w-auto bg-emerald-600 text-white py-3 px-8 rounded-md hover:bg-emerald-700"
                onClick={() => setShowContact(true)}
              >
                I Want This Book
              </button>
            ) : (
              <div className="bg-blue-50 border border-blue-200 rounded-md p-4">
                <h3 className="text-lg font-semibold text-blue-800 mb-2">Contact the Donor</h3>
                <p className="text-blue-800 mb-4">
                  For your safety, we use our secure messaging system to connect you with the book donor.
                </p>
                <button 
                  className="bg-blue-600 text-white py-3 px-6 rounded-md hover:bg-blue-700 flex items-center"
                  onClick={() => setCurrentPage('messages')}
                >
                  <ChatBubbleLeftRightIcon className="h-5 w-5 mr-2" />
                  Send Message to {book.owner?.full_name || 'Donor'}
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

// MessagesPage Component
const MessagesPage = ({ setCurrentPage, currentUser }) => {
  const [activeConversation, setActiveConversation] = useState(0);
  const [messageText, setMessageText] = useState('');
  
  const conversations = [
    {
      id: 1,
      with: "Alex Johnson",
      book: "To Kill a Mockingbird",
      messages: [
        { sender: "Alex Johnson", text: "Hi there! Are you interested in picking up this book?", time: "2 days ago" },
        { sender: "You", text: "Yes, I'd love to get it. When would be a good time to meet?", time: "1 day ago" },
        { sender: "Alex Johnson", text: "How about this Saturday at 2pm? We could meet at the local library.", time: "1 day ago" }
      ]
    },
    {
      id: 2,
      with: "Sam Wilson",
      book: "1984",
      messages: [
        { sender: "Sam Wilson", text: "Hello! I saw you're interested in 1984.", time: "3 hours ago" },
        { sender: "You", text: "Yes, it's one of my favorite classics!", time: "2 hours ago" }
      ]
    }
  ];
  
  const sendMessage = (e) => {
    e.preventDefault();
    // In a real app, this would send the message
    setMessageText('');
  };
  
  return (
    <div className="container mx-auto py-8 px-4">
      <h2 className="text-2xl font-bold mb-6">Messages</h2>
      <div className="bg-white rounded-lg shadow-md overflow-hidden">
        <div className="flex flex-col md:flex-row h-[600px]">
          {/* Conversations list */}
          <div className="md:w-1/3 lg:w-1/4 border-r">
            <div className="p-4 border-b bg-gray-50">
              <h3 className="font-semibold">Conversations</h3>
            </div>
            <div className="overflow-y-auto h-[calc(600px-56px)]">
              {conversations.map((convo, index) => (
                <div 
                  key={convo.id} 
                  className={`p-4 border-b cursor-pointer hover:bg-gray-50 ${activeConversation === index ? 'bg-blue-50' : ''}`}
                  onClick={() => setActiveConversation(index)}
                >
                  <div className="font-medium">{convo.with}</div>
                  <div className="text-sm text-gray-600">Re: {convo.book}</div>
                  <div className="text-xs text-gray-500 mt-1">
                    {convo.messages[convo.messages.length - 1].time}
                  </div>
                </div>
              ))}
            </div>
          </div>
          
          {/* Message area */}
          <div className="md:w-2/3 lg:w-3/4 flex flex-col">
            <div className="p-4 border-b bg-gray-50 flex justify-between items-center">
              <div>
                <h3 className="font-semibold">{conversations[activeConversation].with}</h3>
                <div className="text-sm text-gray-600">Re: {conversations[activeConversation].book}</div>
              </div>
              <button 
                className="text-emerald-600 hover:underline text-sm"
                onClick={() => setCurrentPage('home')}
              >
                View Book
              </button>
            </div>
            <div className="flex-grow overflow-y-auto p-4 bg-gray-100">
              {conversations[activeConversation].messages.map((msg, i) => (
                <div 
                  key={i} 
                  className={`mb-4 flex ${msg.sender === "You" ? "justify-end" : "justify-start"}`}
                >
                  <div 
                    className={`rounded-lg py-2 px-4 max-w-xs ${
                      msg.sender === "You" 
                        ? "bg-emerald-600 text-white" 
                        : "bg-white border border-gray-200"}`}
                  >
                    <div>
                      <p>{msg.text}</p>
                      <div className={`text-xs mt-1 ${msg.sender === "You" ? "text-emerald-100" : "text-gray-500"}`}>
                        {msg.time}
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
            <div className="p-4 border-t">
              <form onSubmit={sendMessage} className="flex gap-2">
                <input 
                  type="text" 
                  className="flex-grow border rounded-md p-2"
                  placeholder="Type your message..." 
                  value={messageText}
                  onChange={(e) => setMessageText(e.target.value)}
                />
                <button 
                  type="submit" 
                  className="bg-emerald-600 text-white py-2 px-4 rounded-md hover:bg-emerald-700"
                >
                  Send
                </button>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

// ProfilePage Component
const ProfilePage = ({ currentUser, setCurrentPage }) => {
  const { logout } = useAuth();
  
  const handleLogout = async () => {
    try {
      await logout();
      setCurrentPage('home');
    } catch (err) {
      console.error('Logout failed:', err);
    }
  };
  
  return (
    <div className="container mx-auto py-8 px-4 max-w-2xl">
      <div className="bg-white rounded-lg shadow-md p-8">
        <h2 className="text-2xl font-bold mb-6">My Profile</h2>
        
        <div className="mb-6">
          <div className="flex items-center justify-center bg-gray-100 rounded-full w-24 h-24 mx-auto mb-4">
            <UserIcon className="h-9 w-9 text-gray-400" />
          </div>
          <h3 className="text-xl font-semibold text-center">{currentUser?.full_name}</h3>
          <p className="text-gray-600 text-center">{currentUser?.email}</p>
        </div>
        
        <div className="bg-gray-50 rounded-md p-4 mb-6">
          <h4 className="font-medium mb-2">Account Information</h4>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <p className="text-sm text-gray-500">Name</p>
              <p>{currentUser?.full_name}</p>
            </div>
            <div>
              <p className="text-sm text-gray-500">Email</p>
              <p>{currentUser?.email}</p>
            </div>
            <div>
              <p className="text-sm text-gray-500">ZIP Code</p>
              <p>{currentUser?.zip_code}</p>
            </div>
            <div>
              <p className="text-sm text-gray-500">Member Since</p>
              <p>May 2025</p>
            </div>
          </div>
        </div>
        
        <div className="flex gap-4">
          <button 
            className="flex-1 bg-gray-200 text-gray-800 py-3 px-4 rounded-md hover:bg-gray-300"
            onClick={() => setCurrentPage('home')}
          >
            Back to Home
          </button>
          <button 
            className="flex-1 bg-red-100 text-red-700 py-3 px-4 rounded-md hover:bg-red-200"
            onClick={handleLogout}
          >
            Log Out
          </button>
        </div>
      </div>
    </div>
  );
};

// Footer Component
const Footer = () => {
  return (
    <footer className="bg-gray-800 text-white py-8">
      <div className="container mx-auto px-4">
        <div className="flex flex-col md:flex-row justify-between">
          <div className="mb-6 md:mb-0">
            <div className="flex items-center space-x-2">
              <img src="/bsc-icon.png" alt="BookShare Community" className="h-4 w-4" />
              <h2 className="text-xl font-bold">BookShare Community</h2>
            </div>
            <p className="mt-2 text-gray-400">Connecting readers and building community through books.</p>
          </div>
          
          <div className="grid grid-cols-2 md:grid-cols-3 gap-8">
            <div>
              <h3 className="text-lg font-semibold mb-3">About</h3>
              <ul className="space-y-2">
                <li className="text-gray-400 hover:text-white cursor-pointer">Our Mission</li>
                <li className="text-gray-400 hover:text-white cursor-pointer">How It Works</li>
                <li className="text-gray-400 hover:text-white cursor-pointer">Community Guidelines</li>
              </ul>
            </div>
            
            <div>
              <h3 className="text-lg font-semibold mb-3">Support</h3>
              <ul className="space-y-2">
                <li className="text-gray-400 hover:text-white cursor-pointer">FAQ</li>
                <li className="text-gray-400 hover:text-white cursor-pointer">Contact Us</li>
                <li className="text-gray-400 hover:text-white cursor-pointer">Safety Tips</li>
              </ul>
            </div>
            
            <div>
              <h3 className="text-lg font-semibold mb-3">Legal</h3>
              <ul className="space-y-2">
                <li className="text-gray-400 hover:text-white cursor-pointer">Privacy Policy</li>
                <li className="text-gray-400 hover:text-white cursor-pointer">Terms of Service</li>
              </ul>
            </div>
          </div>
        </div>
        
        <div className="mt-8 pt-8 border-t border-gray-700 text-center">
          <p className="text-gray-400">© 2025 BookShare Community. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
};

export default BookDonationMarketplace; 