// Best-effort, client-side check for a toy age label. This mirrors the formats the
// backend accepts but is intentionally lenient: the authoritative validation happens
// on save via ToyAgeRange.parse. `metadata` is the `accepted_inputs` payload from
// getToyAgeMetadata().
export function isLikelyValidToyAge(value, metadata) {
  const trimmed = (value || '').trim();
  if (!trimmed) return true;
  if (!metadata) return true;

  const normalized = trimmed.toLowerCase();

  const knownValues = [
    ...(metadata.bucket_labels || []),
    ...(metadata.examples || []),
  ].map((entry) => entry.toLowerCase());
  if (knownValues.includes(normalized)) return true;

  return (metadata.patterns || []).some(({ regex }) => {
    try {
      return new RegExp(regex, 'i').test(trimmed);
    } catch {
      return false;
    }
  });
}

// Hint text derived from the example inputs, e.g. "e.g. 8+, 7+, 3-6 years".
export function toyAgeHint(metadata) {
  const examples = (metadata && metadata.examples) || [];
  if (examples.length === 0) return '';
  return `e.g. ${examples.slice(0, 3).join(', ')}`;
}

// Upper bound used for open-ended ages; mirrors ToyAgeRange::OPEN_MAX on the backend.
const OPEN_MAX = 999;

// Numeric bounds for a canonical browse bucket value like "8-10 years" or "13+ years".
export function parseBucketBounds(bucketValue) {
  const trimmed = (bucketValue || '').trim();
  if (!trimmed) return null;

  const openEnded = trimmed.match(/^(\d+)\s*\+/);
  if (openEnded) return { min: parseInt(openEnded[1], 10), max: null };

  const range = trimmed.match(/^(\d+)\s*-\s*(\d+)/);
  if (range) return { min: parseInt(range[1], 10), max: parseInt(range[2], 10) };

  return null;
}

// Client-side mirror of Toy.overlapping_age_bucket, used for the no-ZIP browse
// fallback. Toys without parsed bounds are excluded when a bucket filter is active.
export function toyMatchesAgeBucket(item, bucketValue) {
  const bounds = parseBucketBounds(bucketValue);
  if (!bounds) return true;
  if (item.min_age == null) return false;

  const itemMax = item.max_age == null ? OPEN_MAX : item.max_age;
  const filterMax = bounds.max == null ? OPEN_MAX : bounds.max;
  return item.min_age <= filterMax && itemMax >= bounds.min;
}
