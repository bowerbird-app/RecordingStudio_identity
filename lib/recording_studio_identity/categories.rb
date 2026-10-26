# frozen_string_literal: true

module RecordingStudioIdentity
  class ConfigurationError < ArgumentError; end

  Category = Data.define(:key, :label, :description, :icon, :fields) do
    def field_label(field)
      configured = fields[field.to_sym]
      return configured if configured.present?

      I18n.t(
        "recording_studio.identity.fields.#{field}",
        default: field.to_s.humanize
      )
    end

    def icon_name
      return if icon.blank?

      Categories::ICON_ALIASES.fetch(icon, icon)
    end
  end

  Creation = Data.define(:title, :description, :continue_label)

  # Host category registry. Keys are normalized once at the configuration boundary.
  module Categories
    FIELD_NAMES = %i[name description image website_url].freeze
    DEFAULT_FIELD_LABELS = {
      name: "Name",
      description: "About",
      image: "Image",
      website_url: "Website"
    }.freeze
    KEY_FORMAT = /\A[a-z][a-z0-9_]*\z/
    ICON_ALIASES = {
      "user-round" => "user",
      "building-2" => "building-office-2",
      "users" => "user-group"
    }.freeze
    DEFAULTS = {
      person: {
        label: "Person",
        description: "Creators, influencers and individuals",
        icon: "user",
        fields: DEFAULT_FIELD_LABELS
      },
      company: {
        label: "Company",
        description: "Businesses and corporations",
        icon: "building-office-2",
        fields: DEFAULT_FIELD_LABELS
      },
      brand: {
        label: "Brand",
        description: "Products and commercial brands",
        icon: "tag",
        fields: DEFAULT_FIELD_LABELS
      },
      organisation: {
        label: "Organisation",
        description: "Clubs, institutions and nonprofits",
        icon: "user-group",
        fields: DEFAULT_FIELD_LABELS
      }
    }.freeze

    module_function

    def defaults
      parse(DEFAULTS)
    end

    def parse(value)
      definitions = hash!(value, "types")
      seen = {}
      definitions.map do |raw_key, definition|
        key = normalize_key(raw_key)
        raise ConfigurationError, "Duplicate identity category #{key.inspect}" if seen[key]

        seen[key] = true
        build(key, definition)
      end
    end

    def creation(value)
      raw = hash!(value || {}, "creation")
      unknown = raw.keys.map(&:to_sym) - %i[title description continue_label]
      raise ConfigurationError, "Unknown creation option(s): #{unknown.join(', ')}" if unknown.any?

      {
        title: optional_string(raw, :title),
        description: raw.key?(:description) || raw.key?("description") ? optional_string(raw, :description) : nil,
        description_set: raw.key?(:description) || raw.key?("description"),
        continue_label: optional_string(raw, :continue_label)
      }
    end

    def normalize_key(raw_key)
      key = raw_key.to_s.strip.downcase
      return key if KEY_FORMAT.match?(key)

      raise ConfigurationError, "Identity category #{raw_key.inspect} is not a usable key"
    end

    def build(key, definition)
      values = hash!(definition, "category #{key}")
      unknown = values.keys.map(&:to_sym) - %i[label description icon fields]
      raise ConfigurationError, "Unknown option(s) for #{key}: #{unknown.join(', ')}" if unknown.any?

      Category.new(
        key: key,
        label: optional_string(values, :label).presence || key.humanize,
        description: optional_string(values, :description),
        icon: optional_string(values, :icon),
        fields: fields(key, values[:fields] || values["fields"])
      )
    end

    def fields(key, value)
      return {} if value.nil?

      raw = hash!(value, "#{key} fields")
      unknown = raw.keys.map(&:to_sym) - FIELD_NAMES
      raise ConfigurationError, "Unknown field label(s) for #{key}: #{unknown.join(', ')}" if unknown.any?

      FIELD_NAMES.each_with_object({}) do |field, labels|
        label = optional_string(raw, field)
        labels[field] = label if label.present?
      end
    end

    def hash!(value, label)
      return value.to_h if value.respond_to?(:to_h) && !value.is_a?(String)

      raise ConfigurationError, "Identity #{label} must be a map"
    end

    def optional_string(hash, key)
      value = hash[key]
      value = hash[key.to_s] if value.nil? && hash.key?(key.to_s)
      return if value.nil?
      return value if value.is_a?(String)

      raise ConfigurationError, "#{key} must be a string"
    end
  end
end
