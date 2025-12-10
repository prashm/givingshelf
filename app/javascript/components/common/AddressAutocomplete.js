import React, { useState, useEffect, useRef } from 'react';
import { AddressAutofill } from '@mapbox/search-js-react';
import axios from '../../lib/axios';

const AddressAutocomplete = ({ 
  value, 
  onChange, 
  onAddressSelect,
  zipCode = null,
  placeholder = "Start typing your street address...",
  disabled = false,
  className = "",
  error = false
}) => {
  const [inputValue, setInputValue] = useState(value || '');
  const [mapboxToken, setMapboxToken] = useState(null);
  const [loading, setLoading] = useState(true);
  const inputRef = useRef(null);

  // Fetch and decode JWT token from backend
  useEffect(() => {
    const fetchMapboxToken = async () => {
      try {
        const response = await axios.get('/api/location/mapbox_token', {
          withCredentials: true
        });
        
        // Decode JWT token (client-side)
        const token = response.data.token;
        const payload = JSON.parse(atob(token.split('.')[1])); // Decode payload
        
        // Check if token is expired
        if (payload.exp && payload.exp < Date.now() / 1000) {
          console.error('Mapbox token expired');
          setMapboxToken(null);
        } else {
          setMapboxToken(payload.mapbox_token);
        }
      } catch (error) {
        console.error('Failed to fetch Mapbox token:', error);
        setMapboxToken(null);
      } finally {
        setLoading(false);
      }
    };

    fetchMapboxToken();
  }, []);

  // Update input value when external value changes
  useEffect(() => {
    setInputValue(value || '');
  }, [value]);

  // Handle input change
  const handleInputChange = (e) => {
    const newValue = e.target.value;
    setInputValue(newValue);
    onChange(newValue);
  };

  // Handle address selection from Mapbox autofill
  const handleRetrieve = (res) => {
    if (!res || !res.features || res.features.length === 0) {
      return;
    }

    const feature = res.features[0];
    if (!feature) {
      return;
    }

    // Extract address components from Mapbox response
    const context = feature.context || [];
    const properties = feature.properties || {};
    
    // Extract street address - try multiple possible property names
    let streetAddress = '';
    if (properties.address_line) {
      streetAddress = properties.address_line;
    } else if (properties.address) {
      streetAddress = properties.address;
    } else if (properties.housenumber && properties.street) {
      streetAddress = `${properties.housenumber} ${properties.street}`.trim();
    } else if (feature.text) {
      streetAddress = feature.text;
    }
    
    // Extract city from context
    const cityContext = context.find(c => c.id?.startsWith('place.'));
    const city = cityContext?.text || '';
    
    // Extract state from context
    const regionContext = context.find(c => c.id?.startsWith('region.'));
    let state = '';
    if (regionContext) {
      state = regionContext.short_code?.toUpperCase() || regionContext.text?.toUpperCase() || '';
    }
    
    // Extract zip code from context
    const postcodeContext = context.find(c => c.id?.startsWith('postcode.'));
    const zipCode = postcodeContext?.text || '';
    
    const addressComponents = {
      street_address: streetAddress,
      city: city,
      state: state,
      zip_code: zipCode,
      full_address: feature.place_name || properties.full_address || streetAddress,
      coordinates: feature.geometry?.coordinates || null
    };
    
    // Update the input value
    setInputValue(addressComponents.street_address || addressComponents.full_address);
    onChange(addressComponents.street_address || addressComponents.full_address);
    
    // Call the callback to update all form fields
    if (onAddressSelect) {
      onAddressSelect(addressComponents);
    }
  };

  if (loading) {
    return (
      <input
        ref={inputRef}
        type="text"
        value={inputValue}
        onChange={handleInputChange}
        placeholder="Loading..."
        disabled={true}
        className={`w-full px-3 py-2 border rounded-md shadow-sm bg-gray-100 ${className}`}
      />
    );
  }
  
  if (!mapboxToken) {
    // Fallback to regular input if Mapbox token is not available
    return (
      <input
        ref={inputRef}
        type="text"
        value={inputValue}
        onChange={handleInputChange}
        placeholder={placeholder}
        disabled={disabled}
        className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 disabled:bg-gray-100 disabled:cursor-not-allowed ${
          error ? 'border-red-500' : 'border-gray-300'
        } ${className}`}
      />
    );
  }

  // According to Mapbox docs, AddressAutofill must be a descendant of a form element
  // The parent component (Profile) already has a form, so this will work
  return (
    <div className={className}>
      <AddressAutofill 
        accessToken={mapboxToken} 
        onRetrieve={handleRetrieve}
        options={{
          country: 'us',
          types: 'address',
          limit: 5
        }}
      >
        <input
          ref={inputRef}
          type="text"
          name="address"
          value={inputValue}
          onChange={handleInputChange}
          placeholder={placeholder}
          disabled={disabled}
          autoComplete="address-line1"
          className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 disabled:bg-gray-100 disabled:cursor-not-allowed ${
            error ? 'border-red-500' : 'border-gray-300'
          }`}
        />
      </AddressAutofill>
    </div>
  );
};

export default AddressAutocomplete;
