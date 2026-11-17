# frozen_string_literal: true

require_relative "errors"
require_relative "image_action_copy"

module RecordingStudioIdentity
  module Api
    module ImageActions
      module_function

      def register!(api)
        register_set_image(api)
        register_remove_image(api)
      end

      def register_set_image(api)
        register_action(
          api, :identity_set_image, SetImage, ImageActionCopy.signed_blob_contract, ImageActionCopy.set_image
        )
      end

      def register_remove_image(api)
        register_action(api, :identity_remove_image, RemoveImage, nil, ImageActionCopy.remove_image)
      end

      def register_action(api, name, handler, input_contract, openapi)
        existing = ::RecordingStudioApi.capability_action(name, api:)
        return if existing&.handler == handler

        ::RecordingStudioApi.register_capability_action(name, **action_options(api, handler, input_contract, openapi))
      end

      def action_options(api, handler, input_contract, openapi)
        {
          capability: :identity_image, version: "1.0.0", http_verb: :post, required_role: :edit,
          handler:, input_contract:, openapi:, api:
        }
      end

      class SetImage
        def self.call(context)
          Errors.wrap do
            context.access_grant.authorize!(recording: context.recording, role: :edit)
            RecordingStudioIdentity.set_image(
              context.recording,
              signed_blob_id: context.params[:signed_blob_id],
              actor: context.actor
            )
          end
        end
      end

      class RemoveImage
        def self.call(context)
          Errors.wrap do
            context.access_grant.authorize!(recording: context.recording, role: :edit)
            RecordingStudioIdentity.remove_image(context.recording, actor: context.actor)
          end
        end
      end
    end
  end
end
