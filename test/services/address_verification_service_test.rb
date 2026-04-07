require "test_helper"

class AddressVerificationServiceTest < ActiveSupport::TestCase
  Candidate = Struct.new(:postal_code, :country_code, :latitude, :longitude)

  test "geocode_zip_code prefers US result for same postal code" do
    service = AddressVerificationService.new

    # Mirrors the production issue: a non-US match can be returned by geocoder.
    candidates = [
      Candidate.new("80027", "EE", 58.3500577, 24.5755367),
      Candidate.new("80027", "US", 39.9940, -105.1030)
    ]

    Geocoder.stub(:search, candidates) do
      coords = service.geocode_zip_code("80027")
      assert_equal({ latitude: 39.9940, longitude: -105.1030 }, coords)
    end
  end

  test "geocode_zip_code falls back to first result when metadata is missing" do
    service = AddressVerificationService.new
    candidates = [ Candidate.new(nil, nil, 39.0, -105.0) ]

    Geocoder.stub(:search, candidates) do
      coords = service.geocode_zip_code("80027")
      assert_equal({ latitude: 39.0, longitude: -105.0 }, coords)
    end
  end
end
