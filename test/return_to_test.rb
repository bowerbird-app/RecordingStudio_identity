# frozen_string_literal: true

require "test_helper"

class ReturnToTest < Minitest::Test
  def setup
    @configuration = RecordingStudioIdentity::Configuration.new
  end

  def test_safe_paths_are_kept
    [
      "/",
      "/welcome",
      "/onboarding/next",
      "/welcome?step=2",
      "/welcome?next=https://example.com",
      "/welcome#done"
    ].each do |path|
      assert_equal path, safe(path), path
    end
  end

  def test_unsafe_paths_are_ignored
    [
      nil,
      "",
      "   ",
      "welcome",
      " /welcome",
      "//evil.example",
      "///evil.example",
      "https://evil.example",
      "https://app.test/welcome",
      "http://evil.example/path",
      "javascript:alert(1)",
      "/\\evil.example",
      "\\\\evil.example",
      "/javascript:alert(1)",
      "/%2f%2fevil.example",
      "/%2Fevil.example",
      "/%5cevil.example",
      "/welcome\nSet-Cookie:x=1",
      "/welcome\t/evil.example"
    ].each do |path|
      assert_nil safe(path), path.inspect
    end
  end

  def test_a_hook_can_reject_a_safe_path_and_cannot_allow_an_unsafe_one
    @configuration.allow_return_to = ->(path) { path == "/welcome" }

    assert_equal "/welcome", safe("/welcome")
    assert_nil safe("/elsewhere")
    assert_nil safe("//evil.example")
    assert_nil safe("https://evil.example/welcome")
  end

  def test_a_missing_hook_allows_every_safe_path
    assert_nil @configuration.allow_return_to
    assert_equal "/welcome", safe("/welcome")
  end

  private

  def safe(path)
    RecordingStudioIdentity::ReturnTo.safe(path, configuration: @configuration)
  end
end
