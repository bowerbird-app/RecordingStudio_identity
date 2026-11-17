# frozen_string_literal: true

module RecordingStudioIdentity
  module Api
    module ImageActionCopy
      IDENTITY_ID_PARAMETER = {
        name: "id", in: "path", required: true,
        description: "The identity recording id. Create, list, and show return it as id.",
        schema: { type: "string" }
      }.freeze

      IDENTITY_JSON = "The identity JSON from show. It includes id, type, parent_id, root_id, " \
                      "created_at, updated_at, name, kind, description, and website_url. " \
                      "The picture is not in this JSON."

      SIGNED_BLOB_ID = "Signed id for this identity. The host enables Attachable create_upload by adding " \
                       ":create_upload to capability_actions in RecordingStudioIdentity::Api.type_options. " \
                       "Or use the signed-in Attachable direct upload route. " \
                       "PUT the file to the returned URL with the returned headers, then pass this id."

      SET_IMAGE_DESCRIPTION = [
        "The picture is the one Attachable image on this identity, stored under the name image.",
        "Use this to store the first picture or replace the current one.",
        "Get signed_blob_id before this call.",
        "This gem leaves create_upload off.",
        "The host enables it by adding :create_upload to capability_actions in RecordingStudioIdentity::Api.type_options.",
        "Or use the signed-in Attachable route recordings/:recording_id/attachments/direct_uploads.",
        "That route returns the signed id as signed_id and does not take an API token.",
        "PUT the file bytes to the upload URL with the returned headers, then pass signed_blob_id here.",
        "A signed id from another recording or another actor is rejected.",
        "Needs edit access. A trashed identity is rejected.",
        "Allowed files are image types (image/*), up to 10 MB. An identity holds one picture.",
        "Replacing revises that attachment recording and restores it when it was trashed."
      ].join(" ")

      REMOVE_IMAGE_DESCRIPTION = [
        "Removes the picture from this identity. The name, kind, description, and website URL stay.",
        "Needs edit access. A trashed identity is rejected.",
        "If there is no picture, or that picture is already trashed, the call succeeds and changes nothing.",
        "Otherwise the attachment is trashed. This API does not restore it.",
        "A later set image revises that same attachment."
      ].join(" ")

      def self.set_image
        {
          title: "Set image",
          summary: "Store or replace the one picture on this identity.",
          description: SET_IMAGE_DESCRIPTION,
          parameters: [IDENTITY_ID_PARAMETER],
          responses: { "200" => { description: IDENTITY_JSON } }
        }
      end

      def self.remove_image
        {
          title: "Remove image",
          summary: "Remove the picture from this identity.",
          description: REMOVE_IMAGE_DESCRIPTION,
          parameters: [IDENTITY_ID_PARAMETER],
          responses: { "200" => { description: IDENTITY_JSON } }
        }
      end

      def self.signed_blob_contract
        {
          reject_unknown: false,
          fields: {
            signed_blob_id: {
              type: :string, required: true, allow_blank: false, description: SIGNED_BLOB_ID
            }
          }
        }
      end
    end
  end
end
