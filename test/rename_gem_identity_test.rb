# frozen_string_literal: true

require "test_helper"

class RenameGemIdentityTest < Minitest::Test
  def test_rename_script_rewrites_leftover_template_homepages
    script = File.read(File.expand_path("../bin/rename_gem", __dir__))

    assert_includes script, "https://github.com/bowerbird-app/\#{@new_name}"
    readme = File.read(File.expand_path("../README.md", __dir__))
    gemspec = File.read(File.expand_path("../recording_studio_identity.gemspec", __dir__))
    assert_includes readme, "https://github.com/bowerbird-app/RecordingStudio_identity"
    assert_includes gemspec, "https://github.com/bowerbird-app/RecordingStudio_identity"
    assert_includes script, "rewrite_leftover_homepages!"
    assert_includes script, "leftover_template_identity?"
    assert_includes script, "README.md"
    assert_includes script, "CHANGELOG.md"
  end
end
