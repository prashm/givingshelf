import { createConsumer } from '@rails/actioncable';

// Create a singleton consumer instance
let consumer = null;

export const getConsumer = () => {
  if (!consumer) {
    // Get the WebSocket URL from the meta tag or use default
    const wsUrl = document.querySelector('meta[name="action-cable-url"]')?.content || 
                  `${window.location.protocol === 'https:' ? 'wss:' : 'ws:'}//${window.location.host}/cable`;
    
    consumer = createConsumer(wsUrl);
  }
  return consumer;
};

// Helper function to create a subscription
export const createSubscription = (channel, callbacks) => {
  const consumer = getConsumer();
  
  const subscription = consumer.subscriptions.create(channel, {
    connected() {
      console.log('ActionCable connected to', channel.channel);
      if (callbacks.connected) {
        callbacks.connected();
      }
    },
    
    disconnected() {
      console.log('ActionCable disconnected from', channel.channel);
      if (callbacks.disconnected) {
        callbacks.disconnected();
      }
    },
    
    received(data) {
      if (callbacks.received) {
        callbacks.received(data);
      }
    },
    
    rejected() {
      console.error('ActionCable subscription rejected for', channel.channel);
      if (callbacks.rejected) {
        callbacks.rejected();
      }
    }
  });
  
  return subscription;
};

// Helper to disconnect the consumer (useful for cleanup)
export const disconnectConsumer = () => {
  if (consumer) {
    consumer.disconnect();
    consumer = null;
  }
};

