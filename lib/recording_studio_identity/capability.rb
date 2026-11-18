# frozen_string_literal: true

module RecordingStudio
  module Capabilities
    module Identities
      def self.to(**options)
        unknown = options.keys - %i[allow trashable]
        if unknown.any?
          raise RecordingStudioIdentity::ConfigurationError, "Unknown identities option(s): #{unknown.join(', ')}"
        end

        allowance = RecordingStudioIdentity::Slots.parse!(options[:allow])
        trashable = RecordingStudioIdentity::Slots.parse_trashable!(options.fetch(:trashable, true))
        RecordingStudio::Capabilities.include_for(:identities, allow: allowance, trashable: trashable) do |parent|
          RecordingStudioIdentity::Slots.sync_parent_limit!(parent, allowance)
        end
      end
    end
  end
end

RecordingStudio.register_capability(
  :identities,
  source: "recording_studio_identity",
  child_recordables: [RecordingStudioIdentity::IDENTITY_TYPE]
)

RecordingStudio.register_capability(
  :identity_image,
  source: "recording_studio_identity"
)
