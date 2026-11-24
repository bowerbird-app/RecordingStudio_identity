# frozen_string_literal: true

require_relative "copy"

module RecordingStudioIdentity
  module McpCopy
    module CurrentCopy
      SHOW_CURRENT_DESCRIPTION =
        "Show the identity on the root this client is signed in to. Send no id and no parent_id. " \
        "That call reads only this client's root. " \
        "A root with no identity is an error. " \
        "A root that allows many identities (allow: :many) is an error. Use show_identity and pass an id."

      UPDATE_CURRENT_DESCRIPTION =
        "Update the identity on the root this client is signed in to. Send no id and no parent_id. " \
        "Send name, description, and website_url at the root, not nested under attributes. kind cannot change. " \
        "That call writes only this client's root. " \
        "A root with no identity is an error. " \
        "A root that allows many identities (allow: :many) is an error. Use update_identity and pass an id."

      CURRENT_COPY = {
        show_current_identity: {
          title: "Show the current identity",
          description: SHOW_CURRENT_DESCRIPTION,
          input: {},
          output: "The identity on this root."
        },
        update_current_identity: {
          title: "Update the current identity",
          description: UPDATE_CURRENT_DESCRIPTION,
          input: Copy::UPDATE_INPUTS,
          output: "The identity after the change."
        }
      }.freeze
    end
  end
end
