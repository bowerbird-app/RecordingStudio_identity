# frozen_string_literal: true

require "uri"

module RecordingStudioIdentity
  class Identity < ApplicationRecord
    self.table_name = "recording_studio_identities"
    self.record_timestamps = false

    CREATE_FIELDS = %i[name kind description website_url].freeze
    UPDATE_FIELDS = %i[name description website_url].freeze
    LIMITS = {
      name: 200,
      description: 5_000,
      website_url: 2_048
    }.freeze

    recording_studio_recordable label: "Identity", plural_label: "Identities", root: false

    include RecordingStudio::Capabilities::Trashable.to
    include RecordingStudio::Capabilities::Attachable.to(
      allowed_content_types: ["image/*"],
      enabled_attachment_kinds: [:image],
      max_file_size: 10.megabytes,
      max_file_count: 1,
      auth_roles: { upload: :edit, revise: :edit, remove: :edit, restore: :edit }
    )

    normalizes :name, :description, :website_url, with: ->(value) { value.to_s.strip.presence }
    normalizes :kind, with: ->(value) { value.to_s.strip.downcase.presence }

    validates :name, presence: true
    validates :kind, presence: true
    LIMITS.each { |field, maximum| validates field, length: { maximum: maximum }, allow_nil: true }
    validate :website_is_http
    validate :kind_is_configured, if: -> { RecordingStudioIdentity.enforcing_category? }

    before_create { self.created_at ||= Time.current }

    def website_href
      uri = parsed_website
      website_url if uri.is_a?(URI::HTTP) && uri.host.present?
    end

    private

    def website_is_http
      return if website_url.blank?
      return if website_href.present?

      errors.add(:website_url, "must be an HTTP or HTTPS URL")
    end

    def kind_is_configured
      return if kind.blank?
      return if RecordingStudioIdentity.category(kind)

      errors.add(:kind, "is not a configured identity category")
    end

    def parsed_website
      URI.parse(website_url)
    rescue URI::InvalidURIError
      nil
    end
  end
end
