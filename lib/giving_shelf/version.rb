module GivingShelf
  module Version
    COMPANY_NAME = "SimplifAI LLC"
    COMPANY_URL = "https://simplifai.llc"
    APP_VERSION = "2.3.2"
    COPYRIGHT_START_YEAR = 2025

    def self.copyright_end_year
      Date.current.year
    end

    def self.copyright_year
      if COPYRIGHT_START_YEAR == copyright_end_year
        COPYRIGHT_START_YEAR.to_s
      else
        "#{COPYRIGHT_START_YEAR} - #{copyright_end_year}"
      end
    end
  end
end
