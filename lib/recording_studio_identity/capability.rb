# frozen_string_literal: true

module RecordingStudio
  module Capabilities
    module Identities
      def self.to(**options)
        unknown = options.keys - [:allow]
        if unknown.any?
          raise RecordingStudioIdentity::ConfigurationError, "Unknown identities option(s): #{unknown.join(', ')}"
        end

        RecordingStudio::Capabilities.include_for(
          :identities,
          allow: RecordingStudioIdentity::Slots.parse!(options[:allow])
        )
      end
    end
  end
end

RecordingStudio.register_capability(
  :identities,
  source: "recording_studio_identity",
  child_recordables: [RecordingStudioIdentity::IDENTITY_TYPE]
)
