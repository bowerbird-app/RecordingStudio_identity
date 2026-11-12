# frozen_string_literal: true

module RecordingStudioIdentity
  module Api
    module Errors
      module_function

      def wrap
        yield
      rescue RecordingStudioIdentity::NotFound, RecordingStudioIdentity::ParentNotAllowed => e
        raise ::RecordingStudioApi::NotFoundError, e.message
      rescue RecordingStudioIdentity::NotAuthorized => e
        raise ::RecordingStudioApi::AuthorizationError, e.message
      rescue RecordingStudioIdentity::Invalid, RecordingStudioIdentity::IdentityAlreadyExists,
             RecordingStudioIdentity::IdentityIntegrityError, RecordingStudioIdentity::Trashed,
             RecordingStudioIdentity::ImageRejected, ArgumentError => e
        raise ::RecordingStudioApi::InvalidActionInputError, e.message
      end
    end
  end
end
