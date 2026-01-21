import React from 'react';

const StatsSection = ({
  title,
  stats = [],
  className = '',
  columnsClassName
}) => {
  const visibleStats = (stats || []).filter(s => s && s.label !== undefined);
  const columns = columnsClassName || `md:grid-cols-${Math.min(visibleStats.length, 4)}`;

  return (
    <div className={`bg-white rounded-lg p-8 shadow-md ${className}`}>
      {title && <h2 className="text-2xl font-bold mb-6 text-center">{title}</h2>}
      <div className={`grid gap-6 text-center ${columns}`}>
        {visibleStats.map((stat) => (
          <div key={stat.key || stat.label}>
            <div className={`text-3xl font-bold mb-2 ${stat.valueClassName || 'text-blue-600'}`}>
              {stat.value}
            </div>
            <div className="text-gray-600">{stat.label}</div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default StatsSection;

