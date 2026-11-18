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

      SIGNED_BLOB_ID = "Signed id from create_upload on this identity. " \
                       "PUT the file bytes to upload.url with upload.headers, then pass this id."

      SET_IMAGE_DESCRIPTION = [
        "The picture is the one Attachable image on this identity, stored under the name image.",
        "Use this to store the first picture or replace the current one.",
        "Call create_upload on this identity first.",
        "It returns signed_blob_id, upload.url, and upload.headers.",
        "PUT the file bytes to upload.url with upload.headers, then pass signed_blob_id here.",
        "A signed id from another recording or another actor is rejected.",
        "Needs edit access. A trashed identity is rejected.",
        "Allowed files are image types (image/*), up to 10 MB. An identity holds one picture.",
        "Replacing revises that attachment recording and restores it when it was trashed."
      ].join(" ")

      CREATE_UPLOAD_SUMMARY = "Prepare an upload for this identity's picture."

      CREATE_UPLOAD_DESCRIPTION = [
        "Prepares a direct upload for this identity's one picture. This step does not attach the file.",
        "The path id is the identity recording id. Create, list, and show return it as id.",
        "Send filename, byte_size, checksum, and content_type.",
        "checksum is the file's MD5, Base64-encoded.",
        "content_type must be an image type (image/*). byte_size must be at most 10 MB.",
        "Returns signed_blob_id, upload.url, upload.headers, and expires_at.",
        "PUT the file bytes to upload.url with upload.headers, then call identity_set_image with signed_blob_id.",
        "The upload URL and the signed id expire. The default lifetime is 5 minutes.",
        "The signed id only works for this identity and the same actor.",
        "Needs edit access."
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

      def self.document_create_upload
        return unless defined?(::RecordingStudioAttachable::Api)

        RecordingStudioAttachable::Api.override_openapi(
          type: TYPE,
          action: :create_upload,
          title: "Upload identity picture",
          summary: CREATE_UPLOAD_SUMMARY,
          description: CREATE_UPLOAD_DESCRIPTION
        )
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
