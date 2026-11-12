# frozen_string_literal: true

class Agency < ApplicationRecord
  recording_studio_recordable label: "Agency", plural_label: "Agencies", root: true
  RecordingStudio.enable_capability(:accessible, on: self) if defined?(RecordingStudioAccessible)
  RecordingStudio.enable_capability(:api_access_point, on: self) if defined?(RecordingStudioApi)
  include RecordingStudio::Capabilities::Identities.to(allow: :many)
end
