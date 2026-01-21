import React, { useMemo } from 'react';

const PopularGenresSection = ({
  title = 'Popular Genres',
  books = [],
  maxGenres = 5,
  onGenreClick
}) => {
  const popularGenres = useMemo(() => {
    if (!Array.isArray(books) || books.length === 0) return [];

    const genreCounts = {};
    books.forEach((book) => {
      if (book?.genre) {
        genreCounts[book.genre] = (genreCounts[book.genre] || 0) + 1;
      }
    });

    return Object.entries(genreCounts)
      .sort(([, a], [, b]) => b - a)
      .slice(0, maxGenres)
      .map(([genre]) => genre);
  }, [books, maxGenres]);

  if (popularGenres.length === 0) return null;

  return (
    <div className="mb-12">
      <h2 className="text-2xl font-bold mb-6">{title}</h2>
      <div className="flex flex-wrap gap-3">
        {popularGenres.map((genre) => (
          <button
            key={genre}
            type="button"
            onClick={() => onGenreClick?.(genre)}
            className="bg-white px-4 py-2 rounded-full border border-gray-200 hover:border-blue-300 hover:bg-blue-50 transition-colors"
          >
            {genre}
          </button>
        ))}
      </div>
    </div>
  );
};

export default PopularGenresSection;

