# frozen_string_literal: true

RecordingStudioIdentity.configure do |config|
  # config.label = "Identity"
  # config.plural_label = "Identities"
  #
  # config.types = {
  #   person: {
  #     label: "Person",
  #     description: "Creators, influencers and individuals",
  #     icon: "user",
  #     fields: { name: "Name", description: "About", image: "Image", website_url: "Website" }
  #   }
  # }
  #
  # config.creation = {
  #   title: "What would you like to represent?",
  #   # Kept on the config object. The category screen does not render it.
  #   description: "Choose the type of identity you'd like to create.",
  #   continue_label: "Continue"
  # }
  #
  # Optional. The screens already allow a relative return_to that starts with
  # one slash. Return false to ignore that path.
  # config.allow_return_to = ->(path) { path.start_with?("/onboarding") }
  #
  # Optional. Attachable calls this for the identity picture. Leave it unset
  # and an anonymous visitor cannot open the file. call(action:, actor:,
  # recording:, role:) returns true or false. recording is the identity.
  # class PublicIdentityImage
  #   def self.call(action:, actor:, recording:, role:)
  #     return true if action.to_sym == :view && public_press_center?(recording)
  #
  #     RecordingStudioAccessible::Authorization.allowed?(actor:, recording:, role:)
  #   end
  #
  #   def self.public_press_center?(_recording)
  #     false
  #   end
  # end
  # config.image_view_policy = PublicIdentityImage
end
