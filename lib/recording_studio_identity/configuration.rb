# frozen_string_literal: true

module RecordingStudioIdentity
  class Configuration
    attr_reader :hooks, :categories
    attr_writer :label, :plural_label

    def initialize
      @hooks = RecordingStudio::Hooks.new
      @categories = Categories.defaults
      @creation_overrides = {}
      @label = nil
      @plural_label = nil
    end

    def terminology
      Terminology.new(label: @label, plural_label: @plural_label)
    end

    def label
      terminology.label
    end

    def plural_label
      terminology.plural_label
    end

    def types
      categories
    end

    def types=(value)
      @categories = Categories.parse(value)
    end

    def creation=(value)
      @creation_overrides = Categories.creation(value)
    end

    def creation
      raw = @creation_overrides
      Creation.new(
        title: raw[:title].presence || copy("creation.title", "What would you like to represent?"),
        description: creation_description(raw),
        continue_label: raw[:continue_label].presence || copy("creation.continue_label", "Continue")
      )
    end

    def category(key)
      normalized = key.to_s.strip.downcase
      categories.find { |category| category.key == normalized }
    end

    def to_h
      {
        label: label, plural_label: plural_label,
        types: categories.map(&:key),
        creation: {
          title: creation.title,
          description: creation.description,
          continue_label: creation.continue_label
        },
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
    end

    private

    def creation_description(raw)
      return raw[:description].presence if raw[:description_set]

      copy("creation.description", "Choose the type of identity you'd like to create.").presence
    end

    def copy(key, default)
      I18n.t("recording_studio.identity.#{key}", **terminology.interpolations, default: default)
    end
  end
end
