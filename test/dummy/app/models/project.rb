# frozen_string_literal: true

class Project < ApplicationRecord
  recording_studio_recordable label: "Project", plural_label: "Projects", root: false,
                              allowed_parent_types: ["Workspace"]
  include RecordingStudio::Capabilities::Identities.to(allow: :many)
end
