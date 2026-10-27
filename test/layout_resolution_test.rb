# frozen_string_literal: true

require "test_helper"

class LayoutResolutionTest < Minitest::Test
  def test_engine_and_dummy_controllers_delegate_to_the_configuration
    engine = File.read(
      File.expand_path("../app/controllers/recording_studio_identity/application_controller.rb", __dir__)
    )
    dummy = File.read(File.expand_path("dummy/app/controllers/application_controller.rb", __dir__))

    assert_includes engine, "recording_studio_layout { RecordingStudioIdentity.configuration.layout }"
    refute_includes engine, "UsesDefaultLayout"
    refute_includes engine, "recording_studio/default_layout"

    assert_includes dummy, "recording_studio_layout { application_layout }"
    refute_includes dummy, "UsesDefaultLayout"
    refute_includes dummy, "recording_studio/default_layout"
  end

  def test_controllers_do_not_hardcode_recording_studio_layouts
    root = File.expand_path("..", __dir__)

    assert_empty RecordingStudio::Layout.hardcoded_layout_paths(root)
    assert_empty RecordingStudio::Layout.hardcoded_layout_paths(File.join(root, "test/dummy"))
  end
end
