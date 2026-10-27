# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioIdentity::Configuration.new
  end

  def test_defaults_include_generic_categories
    keys = @configuration.categories.map(&:key)

    assert_equal %w[person company brand organisation], keys
    assert_equal "Name", @configuration.category("person").field_label(:name)
    assert_equal "About", @configuration.category("person").field_label(:description)
    assert_equal "Website", @configuration.category("company").field_label(:website_url)
    assert_equal "Image", @configuration.category("brand").field_label(:image)
    assert_equal "What would you like to represent?", @configuration.creation.title
    assert_equal "Choose the type of identity you'd like to create.", @configuration.creation.description
    assert_equal "Continue", @configuration.creation.continue_label
    assert_equal "Identity", @configuration.label
    assert_equal "Identities", @configuration.plural_label
    assert_instance_of RecordingStudio::Hooks, @configuration.hooks
  end

  def test_types_reject_duplicate_normalized_keys
    error = assert_raises(RecordingStudioIdentity::ConfigurationError) do
      @configuration.types = { person: { label: "Person" }, Person: { label: "Also a person" } }
    end

    assert_includes error.message, "Duplicate identity category"
  end

  def test_host_field_labels_replace_the_shared_defaults
    locale = File.expand_path("../config/locales/en.yml", __dir__)
    unless I18n.load_path.include?(locale)
      I18n.load_path << locale
      I18n.reload!
    end

    @configuration.types = { person: { fields: { name: "Full name", description: "Biography" } } }
    category = @configuration.category("person")

    assert_equal "Full name", category.field_label(:name)
    assert_equal "Biography", category.field_label(:description)
    assert_equal "Website", category.field_label(:website_url)
  end

  def test_types_reject_unknown_field_labels
    error = assert_raises(RecordingStudioIdentity::ConfigurationError) do
      @configuration.types = { person: { fields: { motto: "Motto" } } }
    end

    assert_includes error.message, "motto"
  end

  def test_label_and_plural_label_replace_the_identity_words
    locale = File.expand_path("../config/locales/en.yml", __dir__)
    unless I18n.load_path.include?(locale)
      I18n.load_path << locale
      I18n.reload!
    end

    @configuration.label = "Press profile"
    @configuration.plural_label = "Press profiles"
    words = @configuration.terminology

    assert_equal "Press profile", words.label
    assert_equal "Press profiles", words.plural_label
    assert_equal "press profile", words.term
    assert_equal "press profiles", words.plural
    assert_equal "a", words.article
    assert_equal "Choose the type of press profile you'd like to create.", @configuration.creation.description
    assert_equal "Press profile", @configuration.to_h.fetch(:label)
    assert_equal "Press profiles", @configuration.to_h.fetch(:plural_label)
    assert_nil @configuration.to_h.fetch(:layout)
  end

  def test_blank_labels_fall_back_to_identity
    @configuration.label = "  "
    @configuration.plural_label = ""

    assert_equal "Identity", @configuration.label
    assert_equal "Identities", @configuration.plural_label
    assert_equal "an", @configuration.terminology.article
  end

  def test_merge_sets_labels
    @configuration.merge!(label: "Profile", plural_label: "Profiles")

    assert_equal "Profile", @configuration.label
    assert_equal "Profiles", @configuration.plural_label
  end

  def test_blank_creation_description_is_omitted
    @configuration.creation = { title: "Represent", description: "  ", continue_label: "Next" }
    creation = @configuration.creation

    assert_equal "Represent", creation.title
    assert_nil creation.description
    assert_equal "Next", creation.continue_label
  end

  def test_merge_updates_known_attributes_and_ignores_unknown_keys
    @configuration.merge!(types: { studio: { label: "Studio" } }, unknown_key: "ignored")

    refute_respond_to @configuration, :unknown_key
    assert_equal ["studio"], @configuration.categories.map(&:key)
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.categories.map(&:key)

    @configuration.merge!(nil)

    assert_equal original, @configuration.categories.map(&:key)
  end

  def test_to_h_reports_registered_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }

    result = @configuration.to_h

    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal %w[person company brand organisation], result.fetch(:types)
  end

  def test_configure_without_block_is_safe
    RecordingStudioIdentity.configure

    assert_kind_of RecordingStudioIdentity::Configuration, RecordingStudioIdentity.configuration
  end

  def test_layout_accepts_nil_strings_false_and_keyword_callables
    assert_nil @configuration.layout

    @configuration.layout = "admin"
    assert_equal "admin", @configuration.layout

    @configuration.layout = false
    assert_equal false, @configuration.layout

    @configuration.layout = nil
    assert_nil @configuration.layout

    callable = ->(controller:) { controller.class.name }
    @configuration.layout = callable
    assert_equal callable, @configuration.layout
    assert_equal callable, @configuration.to_h.fetch(:layout)
  end

  def test_layout_rejects_values_recording_studio_will_not_resolve
    [:application, 1, "", "  ", ->(controller) { controller }].each do |value|
      error = assert_raises(ArgumentError) { @configuration.layout = value }
      assert_match(/layout/, error.message)
      assert_nil @configuration.layout
    end
  end

  def test_merge_sets_layout
    @configuration.merge!(layout: "focused")

    assert_equal "focused", @configuration.layout
  end

  def test_removed_category_icon_alias_uses_a_flatpack_name
    category = RecordingStudioIdentity::Categories.parse(person: { icon: "user-round" }).first

    assert_equal "user", category.icon_name
  end
end
