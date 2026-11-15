# frozen_string_literal: true

RecordingStudio.configure do |config|
  # Registered delegated_type recordables (strings or classes)
  config.recordable_types = [ "Workspace", "Folder", "Page", "Agency", "Project" ]
  config.recordable_types += [
    "RecordingStudio::Access",
    "RecordingStudioApi::ApiClient",
    "RecordingStudioApi::ApiCredential",
    "RecordingStudioApi::ApiAccessToken",
    "RecordingStudioApi::AdminApi"
  ] if defined?(RecordingStudioApi)

  # Require each configured ActiveRecord type to call recording_studio_recordable.
  config.require_recordable_declarations = true

  # Shown in the shared default layout title fallback.
  config.app_name = "Press profiles" if config.respond_to?(:app_name=)

  # Actor resolver for events when no actor is explicitly supplied
  config.actor = -> { Current.actor }

  # Recording Studio refuses record! when this authorizer is missing.
  # Creating a root passes root_recording: nil. A persisted actor may open one.
  # Later writes need Accessible :edit on that root. Access rows written by
  # grant_access / bootstrap_owner_access! go through AccessCreationContext.
  # API provisioning records the client, credential, and token as the
  # ApiClient actor, including when that client's access role is only :view.
  config.authorize_write = lambda { |actor:, action:, root_recording:, recordable:, **|
    next false unless actor.is_a?(ActiveRecord::Base) && action.to_s.strip.present?
    next true if actor.class.name == "RecordingStudioApi::ApiClient"
    next true if root_recording.nil?

    if defined?(RecordingStudio::Access) && recordable.is_a?(RecordingStudio::Access)
      next true if RecordingStudioAccessible::AccessCreationContext.allowed?

      next RecordingStudioAccessible.authorized?(actor: actor, recording: root_recording, role: :admin)
    end

    RecordingStudioAccessible.authorized?(actor: actor, recording: root_recording, role: :edit)
  }

  # Emit ActiveSupport::Notifications events
  config.event_notifications_enabled = true

  # Idempotency behavior for log_event!
  config.idempotency_mode = :return_existing # or :raise

  # Recordable duplication strategy for revisions
  config.recordable_dup_strategy = :dup
end
