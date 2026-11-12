# frozen_string_literal: true

require_relative "errors"

module RecordingStudioIdentity
  module Api
    module ImageActions
      module_function

      def register!(api)
        register_set_image(api)
        register_remove_image(api)
      end

      def register_set_image(api)
        register_action(api, :set_image, SetImage, signed_blob_contract, set_image_docs)
      end

      def register_remove_image(api)
        register_action(api, :remove_image, RemoveImage, nil, remove_image_docs)
      end

      def register_action(api, name, handler, input_contract, openapi)
        return if ::RecordingStudioApi.capability_action(name, api:)

        ::RecordingStudioApi.register_capability_action(name, **action_options(api, handler, input_contract, openapi))
      end

      def action_options(api, handler, input_contract, openapi)
        {
          capability: :attachable, version: "1.0.0", http_verb: :post, required_role: :edit,
          handler:, input_contract:, openapi:, api:
        }
      end

      def signed_blob_contract
        {
          reject_unknown: false,
          fields: { signed_blob_id: { type: :string, required: true, allow_blank: false } }
        }
      end

      def set_image_docs
        {
          summary: "Identity - Set Image",
          description: "Stores or replaces the identity image from a signed blob. Needs Accessible edit on the " \
                       "identity. The identity must not be trashed."
        }
      end

      def remove_image_docs
        {
          summary: "Identity - Remove Image",
          description: "Removes the identity image. Needs Accessible edit on the identity. The identity must not " \
                       "be trashed. No image is a no-op."
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
