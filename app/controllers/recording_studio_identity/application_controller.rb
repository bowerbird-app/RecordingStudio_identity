# frozen_string_literal: true

module RecordingStudioIdentity
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    recording_studio_layout { RecordingStudioIdentity.configuration.layout }
    helper RecordingStudioIdentity::IdentitiesHelper

    protect_from_forgery with: :exception

    rescue_from NotFound, ParentNotAllowed, with: :render_not_found
    rescue_from NotAuthorized, with: :render_forbidden
    rescue_from Trashed, with: :redirect_to_trashed_identity

    helper_method :identity_can?

    private

    def current_identity_actor
      return ::Current.actor if defined?(::Current) && ::Current.respond_to?(:actor) && ::Current.actor

      current_user if respond_to?(:current_user, true)
    end

    def identity_can?(action, recording)
      RecordingStudioIdentity.can?(action, recording, actor: current_identity_actor)
    end

    def authorize_identity!(action, recording)
      return if identity_can?(action, recording)

      raise NotAuthorized, "#{action.to_s.capitalize} is not allowed"
    end

    def string_param(*path)
      value = path.reduce(params) { |scope, key| scope[key] if scope.is_a?(ActionController::Parameters) }
      value.presence if value.is_a?(String)
    end

    def render_not_found
      render_error :not_found,
                   title: identity_copy("errors.not_found", "Not found"),
                   description: identity_copy("errors.page_missing", "This page doesn't exist, or you can't see it.")
    end

    def render_forbidden
      render_error :forbidden,
                   title: identity_copy("errors.not_allowed", "Not allowed"),
                   description: identity_copy(
                     "errors.forbidden_description",
                     "You don't have permission to make this change."
                   )
    end

    def render_error(status, title:, description:)
      @error_title = title
      @error_description = description
      render "recording_studio_identity/identities/error", status: status
    end

    def redirect_to_trashed_identity(error)
      redirect_to identity_path(error.identity),
                  alert: ::RecordingStudioIdentity::Copy.user_message(error.message),
                  status: :see_other
    end

    def identity_copy(key, default, **)
      ::RecordingStudioIdentity::Copy.t(key, default: default, **)
    end
  end
end
