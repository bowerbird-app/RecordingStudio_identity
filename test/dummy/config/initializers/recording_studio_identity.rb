# frozen_string_literal: true

RecordingStudioIdentity.configure do |config|
  field_labels = {
    name: "Name",
    description: "About",
    image: "Image",
    website_url: "Website"
  }

  config.types = {
    person: {
      label: "Person",
      description: "Creators, influencers and individuals",
      icon: "user-round",
      fields: field_labels
    },
    company: {
      label: "Company",
      description: "Businesses and corporations",
      icon: "building-2",
      fields: field_labels
    },
    brand: {
      label: "Brand",
      description: "Products and commercial brands",
      icon: "tag",
      fields: field_labels
    },
    organisation: {
      label: "Organisation",
      description: "Clubs, institutions and nonprofits",
      icon: "users",
      fields: field_labels
    }
  }

  config.creation = {
    title: "What would you like to represent?",
    description: "Choose the type of identity you'd like to create.",
    continue_label: "Continue"
  }
end
