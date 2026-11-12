# frozen_string_literal: true

class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
  RecordingStudio.enable_capability(:accessible, on: self) if defined?(RecordingStudioAccessible)
  RecordingStudio.enable_capability(:api_access_point, on: self) if defined?(RecordingStudioApi)
  include RecordingStudio::Capabilities::Identities.to(allow: :one)
end
