# frozen_string_literal: true

module RecordingStudioIdentity
  module McpCopy
    module Copy
      TYPE_DESCRIPTION =
        "An identity is the public name, kind, about text, website, and optional picture for a person, " \
        "company, brand, or organisation. Pass that parent's recording id as parent_id. The workspace " \
        "identity lives under the workspace. The press center identity lives under the press center. " \
        "Create the identity before you set its picture. Prepare the file with create_upload, then call " \
        "identity_set_image. A one-slot parent (allow: :one, for example a press center) " \
        "that already has an identity rejects a second create. A parent that allows many (allow: :many, " \
        "for example Agency or Project) can hold several."

      LIST_DESCRIPTION =
        "#{TYPE_DESCRIPTION} List identities under a parent. Pass that parent's recording id as parent_id. " \
        "Workspace and press center identities are the same type. Tell them apart by parent_id.".freeze

      SHOW_DESCRIPTION =
        "#{TYPE_DESCRIPTION} Show one identity by recording id. Use list or a create result to get ids.".freeze

      CREATE_DESCRIPTION =
        "#{TYPE_DESCRIPTION} Create the identity under a parent. Pass that parent's recording id as parent_id. " \
        "Send name, kind, description, and website_url at the root, not nested under attributes. name and kind " \
        "are required. kind must be a configured category and cannot change later. description and website_url " \
        "are optional. A one-slot parent that already has an identity rejects a second create. " \
        "A parent that allows many can hold several.".freeze

      UPDATE_DESCRIPTION =
        "#{TYPE_DESCRIPTION} Update an identity. Pass its recording id as id. The identity must already exist. " \
        "Send name, description, and website_url at the root, not nested under attributes. kind cannot change.".freeze

      SET_IMAGE_DESCRIPTION = [
        "Sets or replaces the one picture on this identity.",
        TYPE_DESCRIPTION,
        "Pass the identity recording id as id.",
        "Call create_upload first.",
        Api::ImageActionCopy::CREATE_UPLOAD_RETURNS,
        Api::ImageActionCopy::PUT_THEN_PASS_SIGNED_BLOB,
        Api::ImageActionCopy::SIGNED_ID_REJECTED,
        Api::ImageActionCopy::TRASHED_IDENTITY_REJECTED,
        Api::ImageActionCopy::ALLOWED_IMAGE_FILES
      ].join(" ")

      REMOVE_IMAGE_DESCRIPTION = [
        Api::ImageActionCopy::REMOVE_KEEPS_FIELDS,
        TYPE_DESCRIPTION,
        "Pass the identity recording id as id.",
        Api::ImageActionCopy::TRASHED_IDENTITY_REJECTED,
        Api::ImageActionCopy::REMOVE_NO_PICTURE
      ].join(" ")

      NAME_FIELD = "Display name for this identity."
      KIND_FIELD =
        "Category for this identity. Must be a configured category. Set on create. It cannot change later."
      DESCRIPTION_FIELD = "About text for this identity. Leave blank to omit it."
      WEBSITE_FIELD = "HTTP or HTTPS website for this identity. Leave blank to omit it."
      SIGNED_BLOB_FIELD = Api::ImageActionCopy::SIGNED_BLOB_ID

      CREATE_INPUTS = {
        "name" => { description: NAME_FIELD },
        "kind" => { description: KIND_FIELD },
        "description" => { description: DESCRIPTION_FIELD },
        "website_url" => { description: WEBSITE_FIELD }
      }.freeze

      UPDATE_INPUTS = {
        "name" => { description: NAME_FIELD },
        "description" => { description: DESCRIPTION_FIELD },
        "website_url" => { description: WEBSITE_FIELD }
      }.freeze

      SET_IMAGE_INPUTS = {
        "signed_blob_id" => { description: SIGNED_BLOB_FIELD }
      }.freeze

      CRUD_COPY = {
        list: {
          title: "List identities",
          description: LIST_DESCRIPTION,
          input: {},
          output: "The identities under that parent."
        },
        show: {
          title: "Show identity",
          description: SHOW_DESCRIPTION,
          input: {},
          output: "The identity for that id."
        },
        create: {
          title: "Create identity",
          description: CREATE_DESCRIPTION,
          input: CREATE_INPUTS,
          output: "The created identity."
        },
        update: {
          title: "Update identity",
          description: UPDATE_DESCRIPTION,
          input: UPDATE_INPUTS,
          output: "The identity after the change."
        }
      }.freeze

      ACTION_COPY = {
        identity_set_image: {
          title: "Set image",
          description: SET_IMAGE_DESCRIPTION,
          input: SET_IMAGE_INPUTS,
          output: Api::ImageActionCopy::IDENTITY_JSON
        },
        identity_remove_image: {
          title: "Remove image",
          description: REMOVE_IMAGE_DESCRIPTION,
          input: {},
          output: Api::ImageActionCopy::IDENTITY_JSON
        }
      }.freeze
    end
  end
end
