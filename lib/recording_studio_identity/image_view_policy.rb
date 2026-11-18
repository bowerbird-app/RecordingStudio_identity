# frozen_string_literal: true

module RecordingStudioIdentity
  # Attachable treats an authorize_with that responds to call as the whole
  # decision. This object responds to call only while image_view_policy is set,
  # so an unset policy leaves Attachable on its Accessible role check.
  class ImageViewPolicy
    def self.respond_to?(method, *)
      return host_policy? if method.to_sym == :call

      super
    end

    def self.call(action:, actor:, recording:, role:)
      policy = RecordingStudioIdentity.configuration.image_view_policy
      raise NoMethodError, "image_view_policy is not configured" unless policy.respond_to?(:call)

      policy.call(action: action, actor: actor, recording: recording, role: role)
    end

    def self.host_policy?
      RecordingStudioIdentity.configuration.image_view_policy.respond_to?(:call)
    end

    private_class_method :host_policy?
  end
end
