# frozen_string_literal: true

RecordingStudioIdentity.configure do |config|
  config.types = {
    person: {
      label: "Person",
      description: "Creators, influencers and individuals",
      icon: "user-round",
      fields: {
        name: "Full name",
        description: "Biography",
        image: "Profile photo",
        website_url: "Website"
      }
    },
    company: {
      label: "Company",
      description: "Businesses and corporations",
      icon: "building-2",
      fields: {
        name: "Company name",
        description: "About the company",
        image: "Company logo",
        website_url: "Website"
      }
    },
    brand: {
      label: "Brand",
      description: "Products and commercial brands",
      icon: "tag"
    },
    organisation: {
      label: "Organisation",
      description: "Clubs, institutions and nonprofits",
      icon: "users"
    }
  }

  config.creation = {
    title: "What would you like to represent?",
    description: "Choose the type of identity you'd like to create.",
    continue_label: "Continue"
  }
end
