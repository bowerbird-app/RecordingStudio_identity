class ApplicationController < ActionController::Base
  include RecordingStudio::RootSwitchable::ControllerSupport

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  recording_studio_layout { application_layout }

  before_action :authenticate_user!
  before_action :set_current_actor

  private

  # Root switchable calls this by name when config.layout is :application_layout.
  def application_layout
    return "application" if devise_controller?

    resolved = RecordingStudio::Layout.resolve(RecordingStudioIdentity.configuration.layout, controller: self)
    return resolved unless resolved.nil?

    RecordingStudio.configuration.resolved_layout(controller: self)
  end

  def set_current_actor
    Current.actor = current_user
  end
end
