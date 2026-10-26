# frozen_string_literal: true

require "i18n"

module RecordingStudioIdentity
  # Maps known English exception text to locale keys at render time.
  module Copy
    PREFIX = "recording_studio.identity"

    STATIC_MESSAGE_KEYS = {
      "Only one identity is allowed here" => "messages.identity_taken",
      "An identity can have only one image" => "messages.image_taken",
      "An identity can't be added here." => "flashes.cant_add",
      "Choose an image to upload." => "flashes.choose_image",
      "The image was updated." => "flashes.image_updated",
      "The image was removed." => "flashes.image_removed",
      "Not found" => "errors.not_found",
      "This page doesn't exist, or you can't see it." => "errors.page_missing",
      "Not allowed" => "errors.not_allowed",
      "You don't have permission to make this change." => "errors.forbidden_description"
    }.freeze

    NAME_MESSAGE_PATTERNS = [
      [/\A(.+) was added\.\z/, "flashes.was_added", :name],
      [/\A(.+) was saved\.\z/, "flashes.was_saved", :name],
      [/\A(.+) is in the trash\.\z/, "flashes.in_trash", :name],
      [/\A(.+) was restored\.\z/, "flashes.was_restored", :name],
      [/\AYou can't edit (.+)\.\z/, "flashes.cant_edit", :name],
      [/\A(.+) is already the identity here\z/, "flashes.already_identity", :name],
      [/\ARestore (.+) before changing it\z/, "flashes.restore_before_change", :name]
    ].freeze

    COUNT_MESSAGE_PATTERNS = [
      [
        /\AOnly one identity is allowed here, but (\d+) identities are recorded\z/,
        "flashes.integrity_recorded",
        :count
      ]
    ].freeze

    module_function

    def t(key, **)
      I18n.t("#{PREFIX}.#{key}", **RecordingStudioIdentity.configuration.terminology.interpolations, **)
    end

    def user_message(message)
      english = message.to_s
      return english if english.blank?
      return t(STATIC_MESSAGE_KEYS[english], default: english) if STATIC_MESSAGE_KEYS.key?(english)

      mapped = translate_pattern_message(english, NAME_MESSAGE_PATTERNS)
      return mapped if mapped

      mapped = translate_count_message(english)
      return mapped if mapped

      english
    end

    def translate_pattern_message(english, patterns)
      patterns.each do |pattern, key, capture|
        match = pattern.match(english)
        next unless match

        return t(key, capture => match[1], default: english)
      end
      nil
    end

    def translate_count_message(english)
      COUNT_MESSAGE_PATTERNS.each do |pattern, key, capture|
        match = pattern.match(english)
        next unless match

        return t(key, capture => match[1], default: english)
      end
      nil
    end
  end
end
