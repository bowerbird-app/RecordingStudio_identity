# frozen_string_literal: true

require "test_helper"

class CopyTest < Minitest::Test
  def test_user_message_maps_known_english_and_passes_the_rest_through
    assert_equal "  ", RecordingStudioIdentity::Copy.user_message("  ")
    assert_equal "Only one identity is allowed here",
                 RecordingStudioIdentity::Copy.user_message("Only one identity is allowed here")
    assert_equal "Ada was added.", RecordingStudioIdentity::Copy.user_message("Ada was added.")
    assert_equal "Only one identity is allowed here, but 2 identities are recorded",
                 RecordingStudioIdentity::Copy.user_message(
                   "Only one identity is allowed here, but 2 identities are recorded"
                 )
    assert_equal "Leave this alone", RecordingStudioIdentity::Copy.user_message("Leave this alone")
  end

  def test_user_message_uses_the_configured_term
    locale = File.expand_path("../config/locales/en.yml", __dir__)
    unless I18n.load_path.include?(locale)
      I18n.load_path << locale
      I18n.reload!
    end

    configuration = RecordingStudioIdentity.configuration
    previous_label = configuration.instance_variable_get(:@label)
    previous_plural = configuration.instance_variable_get(:@plural_label)
    configuration.label = "Press profile"
    configuration.plural_label = "Press profiles"

    assert_equal "Only one press profile is allowed here",
                 RecordingStudioIdentity::Copy.user_message("Only one identity is allowed here")
    assert_equal "A press profile can have only one image",
                 RecordingStudioIdentity::Copy.user_message("An identity can have only one image")
    assert_equal "Only one press profile is allowed here, but 2 press profiles are recorded",
                 RecordingStudioIdentity::Copy.user_message(
                   "Only one identity is allowed here, but 2 identities are recorded"
                 )
    assert_equal "Ada is already the press profile here",
                 RecordingStudioIdentity::Copy.user_message("Ada is already the identity here")
    assert_equal "Add press profile", RecordingStudioIdentity::Copy.t("titles.add")
    assert_equal "Edit press profile", RecordingStudioIdentity::Copy.t("titles.edit")
    assert_equal "Restore press profile", RecordingStudioIdentity::Copy.t("actions.restore_identity")
    assert_equal "+ Press profile", RecordingStudioIdentity::Copy.t("actions.add_identity_plus")
    assert_equal "Press profiles", RecordingStudioIdentity::Copy.t("titles.index")
    assert_equal "No press profile yet", RecordingStudioIdentity::Copy.t("empty.no_identity_title")
    assert_equal "No press profiles yet", RecordingStudioIdentity::Copy.t("empty.no_identities_title")
  ensure
    configuration.label = previous_label
    configuration.plural_label = previous_plural
  end
end
