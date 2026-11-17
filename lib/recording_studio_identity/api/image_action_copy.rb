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

      SIGNED_BLOB_ID = "Signed id from an Attachable direct upload prepared for this identity. " \
                       "create_upload returns it as signed_blob_id. PUT the file bytes to upload.url " \
                       "with upload.headers first. This resource does not enable create_upload."

      SET_IMAGE_DESCRIPTION = [
        "The picture is the one Attachable image on this identity, stored under the name image.",
        "Use this to store the first picture or replace the current one.",
        "Prepare the file with Attachable create_upload for this same identity.",
        "create_upload returns signed_blob_id, upload.url, and upload.headers.",
        "PUT the file bytes to upload.url with upload.headers, then pass signed_blob_id here.",
        "This resource does not enable create_upload, attach, or import_attachment.",
        "A signed id from another recording or another actor is rejected.",
        "The signed-in upload route is recordings/:recording_id/attachments/direct_uploads on the Attachable engine.",
        "It returns the same signed id as signed_id and does not take an API token.",
        "Needs edit access. A trashed identity is rejected.",
        "Allowed files are image types (image/*), up to 10 MB.",
        "An identity holds one picture.",
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
