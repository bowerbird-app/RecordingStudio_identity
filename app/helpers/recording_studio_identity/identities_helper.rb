# frozen_string_literal: true

module RecordingStudioIdentity
  module IdentitiesHelper
    IMAGE_UPLOAD_CONTROLLER = "recording-studio-attachable--attachment-revision-upload"
    IMAGE_UPLOAD_OPTIONS = %i[
      allowed_content_types
      max_file_size
      image_processing_enabled
      image_processing_max_width
      image_processing_max_height
      image_processing_quality
    ].freeze

    def identity_home_path
      main_app.root_path if main_app.respond_to?(:root_path)
    end

    def identity_recording_name(recording)
      recordable = recording.recordable
      return recordable.name if recordable.respond_to?(:name) && recordable.name.present?
      return recordable.title if recordable.respond_to?(:title) && recordable.title.present?

      recording.id
    end

    def identity_recording_type_label(recording)
      RecordingStudio.recordable_type_label(recording.recordable_type)
    end

    def identity_field_error(record, field)
      record.errors.full_messages_for(field).to_sentence.presence
    end

    def identity_field_label(category, field)
      return category.field_label(field) if category

      I18n.t("recording_studio.identity.fields.#{field}", default: field.to_s.humanize)
    end

    def identity_category_label(identity)
      RecordingStudioIdentity.category_for(identity)&.label || identity.recordable.kind
    end

    def identity_image_form_data(auto_submit: false)
      options = identity_image_upload_options
      values = {
        direct_upload_url: main_app.rails_direct_uploads_path,
        signed_blob_field_name: "image[signed_blob_id]",
        auto_submit: auto_submit,
        **options.except(:allowed_content_types)
      }
      prefix = IMAGE_UPLOAD_CONTROLLER.tr("-", "_")

      { controller: IMAGE_UPLOAD_CONTROLLER, action: "submit->#{IMAGE_UPLOAD_CONTROLLER}#handleSubmit" }
        .merge(values.compact.transform_keys { |key| :"#{prefix}_#{key}_value" })
    end

    def identity_image_accept
      Array(identity_image_upload_options[:allowed_content_types]).join(",")
    end

    def identity_form_data(include_image:, unsaved_changes:)
      upload = include_image ? identity_image_form_data(auto_submit: false) : {}
      controllers = [("flat-pack--unsaved-changes" if unsaved_changes), upload.delete(:controller)].compact
      actions = [upload.delete(:action)].compact
      upload[:controller] = controllers.join(" ") if controllers.any?
      upload[:action] = actions.join(" ") if actions.any?
      upload
    end

    def identity_submit_data(include_image:, unsaved_changes:)
      data = {}
      data["flat-pack--unsaved-changes-target"] = "submit" if unsaved_changes
      data[:recording_studio_attachable__attachment_revision_upload_target] = "submitButton" if include_image
      data
    end

    private

    def identity_image_upload_options
      configured = RecordingStudio.capability_options(:attachable, for: Identity.name).to_h
      IMAGE_UPLOAD_OPTIONS.index_with do |option|
        configured.fetch(option) { RecordingStudioAttachable.configuration.public_send(option) }
      end
    end
  end
end
