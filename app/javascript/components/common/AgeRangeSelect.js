import React from 'react';

const AgeRangeSelect = ({
  options = [],
  id = 'age_range',
  name = 'age_range',
  value = '',
  onChange,
  includeAllOption = false,
  allOptionLabel = 'All ages',
  loading = false,
  disabled = false,
  className = 'w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500',
  emptyOptionLabel = 'Select age range (optional)',
}) => {
  return (
    <select
      id={id}
      name={name}
      value={value}
      onChange={onChange}
      disabled={disabled || loading}
      className={className}
      style={{ appearance: 'auto' }}
    >
      {includeAllOption ? (
        <option value="">{allOptionLabel}</option>
      ) : (
        <option value="">{emptyOptionLabel}</option>
      )}
      {options.map(({ value: optionValue, label }) => (
        <option key={optionValue} value={optionValue}>{label}</option>
      ))}
    </select>
  );
};

export default AgeRangeSelect;
