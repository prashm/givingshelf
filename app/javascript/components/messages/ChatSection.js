import React, { useState, useEffect, useRef } from 'react';
import { fetchChatMessages } from '../../lib/bookRequestsApi';
import { createSubscription } from '../../lib/actionCable';
import { linkifyText } from '../../lib/textUtils';

const ChatSection = ({ bookRequestId, currentUser, otherUser }) => {
  const [messages, setMessages] = useState([]);
  const [newMessage, setNewMessage] = useState('');
  const [isSubscribed, setIsSubscribed] = useState(false);
  const [isPresenceSubscribed, setIsPresenceSubscribed] = useState(false);
  const [activeUsers, setActiveUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [sending, setSending] = useState(false);
  const [isOtherUserTyping, setIsOtherUserTyping] = useState(false);
  const messagesEndRef = useRef(null);
  const chatSubscriptionRef = useRef(null);
  const presenceSubscriptionRef = useRef(null);
  const backupHeartbeatIntervalRef = useRef(null);
  const typingTimeoutRef = useRef(null);
  const typingIndicatorTimeoutRef = useRef(null);

  // Scroll to bottom when messages change
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // Fetch chat history and subscribe to channels on mount
  useEffect(() => {
    if (!bookRequestId || !currentUser) return;

    const initializeChat = async () => {
      try {
        setLoading(true);
        setError(null);

        // Fetch chat history
        const chatHistory = await fetchChatMessages(bookRequestId);
        setMessages(chatHistory);

        // Subscribe to chat channel
        chatSubscriptionRef.current = createSubscription(
          {
            channel: 'BookRequestChatChannel',
            book_request_id: bookRequestId
          },
          {
            connected: () => {
              setIsSubscribed(true);
            },
            received: (data) => {
              if (data.type === 'message' && data.message) {
                setMessages(prev => [...prev, data.message]);
              } else if (data.type === 'typing' && data.user_id === otherUser?.id) {
                // Handle typing indicator from other user
                if (data.is_typing) {
                  setIsOtherUserTyping(true);
                  // Clear existing timeout
                  if (typingIndicatorTimeoutRef.current) {
                    clearTimeout(typingIndicatorTimeoutRef.current);
                  }
                  // Auto-hide after 3 seconds if no new typing event
                  typingIndicatorTimeoutRef.current = setTimeout(() => {
                    setIsOtherUserTyping(false);
                  }, 3000);
                } else {
                  setIsOtherUserTyping(false);
                  if (typingIndicatorTimeoutRef.current) {
                    clearTimeout(typingIndicatorTimeoutRef.current);
                  }
                }
              } else if (data.type === 'error') {
                setError(data.message);
              }
            },
            disconnected: () => {
              setIsSubscribed(false);
            },
            rejected: () => {
              setError('Failed to connect to chat. Please refresh the page.');
            }
          }
        );

        // Subscribe to presence channel
        presenceSubscriptionRef.current = createSubscription(
          {
            channel: 'BookRequestPresenceChannel',
            book_request_id: bookRequestId
          },
          {
            connected: () => {
              setIsPresenceSubscribed(true);
              // Stop backup heartbeat if subscription succeeds
              stopBackupHeartbeat();
            },
            received: (data) => {
              if (data.type === 'presence' && data.users) {
                setActiveUsers(data.users.map(u => u.id));
              }
            },
            disconnected: () => {
              setIsPresenceSubscribed(false);
              setActiveUsers([]);
              // Start backup heartbeat if subscription disconnects
              startBackupHeartbeat();
            },
            rejected: () => {
              console.warn('Presence channel subscription rejected');
              // Start backup heartbeat if subscription is rejected
              startBackupHeartbeat();
            }
          }
        );
      } catch (err) {
        console.error('Error initializing chat:', err);
        setError('Failed to load chat. Please refresh the page.');
      } finally {
        setLoading(false);
      }
    };

    initializeChat();

    // Cleanup on unmount
    return () => {
      if (chatSubscriptionRef.current) {
        chatSubscriptionRef.current.unsubscribe();
      }
      if (presenceSubscriptionRef.current) {
        presenceSubscriptionRef.current.unsubscribe();
      }
      stopBackupHeartbeat();
      if (typingTimeoutRef.current) {
        clearTimeout(typingTimeoutRef.current);
      }
      if (typingIndicatorTimeoutRef.current) {
        clearTimeout(typingIndicatorTimeoutRef.current);
      }
    };
  }, [bookRequestId, currentUser, otherUser]);

  // Backup heartbeat mechanism - only runs if ActionCable subscription fails
  const startBackupHeartbeat = () => {
    // Only start if not already running
    if (backupHeartbeatIntervalRef.current) {
      return;
    }

    console.log('Starting backup heartbeat for presence tracking');
    
    // Send heartbeat every 45 seconds (less than 60s TTL to be safe)
    backupHeartbeatIntervalRef.current = setInterval(() => {
      // Try to send heartbeat via presence channel if it exists
      if (presenceSubscriptionRef.current) {
        try {
          presenceSubscriptionRef.current.send({ type: 'heartbeat' });
        } catch (err) {
          console.warn('Failed to send backup heartbeat:', err);
        }
      }
    }, 45000); // 45 seconds
  };

  const stopBackupHeartbeat = () => {
    if (backupHeartbeatIntervalRef.current) {
      clearInterval(backupHeartbeatIntervalRef.current);
      backupHeartbeatIntervalRef.current = null;
      console.log('Stopped backup heartbeat');
    }
  };

  const handleTyping = () => {
    // Clear existing timeout
    if (typingTimeoutRef.current) {
      clearTimeout(typingTimeoutRef.current);
    }

    // Send typing event after 300ms debounce
    typingTimeoutRef.current = setTimeout(() => {
      if (chatSubscriptionRef.current && isSubscribed) {
        try {
          chatSubscriptionRef.current.send({
            action: 'typing',
            is_typing: true
          });
        } catch (err) {
          console.warn('Failed to send typing event:', err);
        }
      }
    }, 300);
  };

  const handleStopTyping = () => {
    // Clear typing timeout
    if (typingTimeoutRef.current) {
      clearTimeout(typingTimeoutRef.current);
      typingTimeoutRef.current = null;
    }

    // Send stop typing event
    if (chatSubscriptionRef.current && isSubscribed) {
      try {
        chatSubscriptionRef.current.send({
          action: 'typing',
          is_typing: false
        });
      } catch (err) {
        console.warn('Failed to send stop typing event:', err);
      }
    }
  };

  const handleSendMessage = async () => {
    const trimmedMessage = newMessage.trim();
    if (!trimmedMessage || trimmedMessage.length > 1000 || sending) {
      return;
    }

    try {
      setSending(true);
      setError(null);

      // Stop typing indicator before sending
      handleStopTyping();

      // Send message via ActionCable
      chatSubscriptionRef.current?.send({
        content: trimmedMessage
      });

      // Clear input
      setNewMessage('');
    } catch (err) {
      console.error('Error sending message:', err);
      setError('Failed to send message. Please try again.');
    } finally {
      setSending(false);
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  const isOtherUserActive = () => {
    return otherUser && activeUsers.includes(otherUser.id);
  };

  const remainingChars = 1000 - newMessage.length;

  if (loading) {
    return (
      <div className="mt-6 p-4 bg-white rounded-lg shadow-md">
        <p className="text-sm text-gray-500">Loading chat...</p>
      </div>
    );
  }

  return (
    <div className="mt-6 bg-white rounded-lg shadow-md">
      <div className="p-4 border-b border-gray-200">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <h3 className="text-lg font-semibold text-gray-900">
              Chat with {otherUser?.name || 'User'}
            </h3>
            <div className="flex items-center gap-1">
              <div
                className={`w-3 h-3 rounded-full ${
                  isOtherUserActive() ? 'bg-green-500' : 'bg-gray-400'
                }`}
                title={isOtherUserActive() ? 'Active' : 'Inactive'}
              />
              <span className="text-xs text-gray-500">
                {isOtherUserActive() ? 'Active' : 'Inactive'}
              </span>
            </div>
          </div>
        </div>
      </div>

      {error && (
        <div className="p-3 mx-4 mt-4 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {error}
        </div>
      )}

      {/* Chat History */}
      <div className="p-4 h-96 overflow-y-auto bg-gray-50">
        {messages.length === 0 ? (
          <p className="text-sm text-gray-500 text-center py-8">
            No messages yet. Start the conversation!
          </p>
        ) : (
          <div className="space-y-4">
            {messages.map((message) => {
              const isOwnMessage = message.user_id === currentUser?.id;
              return (
                <div
                  key={message.id}
                  className={`flex ${isOwnMessage ? 'justify-end' : 'justify-start'}`}
                >
                  <div
                    className={`max-w-xs lg:max-w-md px-4 py-2 rounded-lg ${
                      isOwnMessage
                        ? 'bg-emerald-600 text-white'
                        : 'bg-white text-gray-900 border border-gray-200'
                    }`}
                  >
                    <div className="text-xs font-medium mb-1 opacity-75">
                      {isOwnMessage ? 'You' : message.user_name}
                    </div>
                    <div className="text-sm whitespace-pre-wrap break-words">
                      {linkifyText(message.content)}
                    </div>
                    <div className="text-xs mt-1 opacity-75">
                      {new Date(message.created_at).toLocaleTimeString([], {
                        hour: '2-digit',
                        minute: '2-digit'
                      })}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Typing Indicator */}
      {isOtherUserTyping && otherUser && (
        <div className="px-4 py-2 border-t border-gray-200 bg-gray-50">
          <p className="text-sm italic text-gray-500">
            {otherUser.name} is typing...
          </p>
        </div>
      )}

      {/* Message Input */}
      <div className="p-4 border-t border-gray-200">
        <div className="flex gap-2">
          <textarea
            value={newMessage}
            onChange={(e) => {
              setNewMessage(e.target.value);
              if (e.target.value.trim()) {
                handleTyping();
              } else {
                handleStopTyping();
              }
            }}
            onBlur={handleStopTyping}
            onKeyPress={handleKeyPress}
            placeholder="Type your message..."
            rows={3}
            maxLength={1000}
            className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent resize-none"
            disabled={sending || !isSubscribed}
          />
          <div className="flex flex-col gap-2">
            <button
              onClick={handleSendMessage}
              disabled={!newMessage.trim() || newMessage.length > 1000 || sending || !isSubscribed}
              className="px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {sending ? 'Sending...' : 'Send'}
            </button>
          </div>
        </div>
        <div className="mt-2 flex justify-between items-center text-xs text-gray-500">
          <span>
            {remainingChars >= 0 ? `${remainingChars} characters remaining` : 'Message too long'}
          </span>
          {!isSubscribed && (
            <span className="text-amber-600">Connecting to chat...</span>
          )}
        </div>
      </div>
    </div>
  );
};

export default ChatSection;

