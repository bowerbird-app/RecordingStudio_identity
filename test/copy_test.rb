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
end
