import axios from './axios';

let cachedToyAgeData = null;
let toyAgeDataPromise = null;

function fetchToyAgeData() {
  if (cachedToyAgeData) return Promise.resolve(cachedToyAgeData);

  if (!toyAgeDataPromise) {
    toyAgeDataPromise = axios
      .get('/api/items/toy_age_ranges')
      .then((response) => {
        cachedToyAgeData = {
          ageRanges: response.data.age_ranges || [],
          acceptedInputs: response.data.accepted_inputs || null,
        };
        return cachedToyAgeData;
      })
      .catch((err) => {
        toyAgeDataPromise = null;
        throw err;
      });
  }

  return toyAgeDataPromise;
}

export async function getToyAgeRanges() {
  const data = await fetchToyAgeData();
  return data.ageRanges;
}

export async function getToyAgeMetadata() {
  const data = await fetchToyAgeData();
  return data.acceptedInputs;
}

export function clearToyAgeRangesCache() {
  cachedToyAgeData = null;
  toyAgeDataPromise = null;
}
