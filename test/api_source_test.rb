# frozen_string_literal: true

require "test_helper"

class ApiSourceTest < Minitest::Test
  def test_register_has_one_api_availability_check
    source = File.read(File.expand_path("../lib/recording_studio_identity/api.rb", __dir__))

    assert_equal 1, source.scan("defined?(::RecordingStudioApi)").size
    refute_includes source, "const_set"
    refute_includes source, "remove_const"
    assert_includes source, "configuration.each_api"
  end

  def test_handlers_call_existing_identity_methods
    resource = File.read(File.expand_path("../lib/recording_studio_identity/api/identity_resource.rb", __dir__))
    images = File.read(File.expand_path("../lib/recording_studio_identity/api/image_actions.rb", __dir__))

    assert_includes resource, "RecordingStudioIdentity.identities(parent)"
    assert_includes resource, "RecordingStudioIdentity.find(context.id)"
    assert_includes resource, "RecordingStudioIdentity.create("
    assert_includes resource, "RecordingStudioIdentity.update("
    assert_includes resource, "access_grant.authorize!(recording: parent, role: :edit)"
    assert_includes resource, "access_grant.authorize!(recording: identity, role: :edit)"
    assert_includes images, "RecordingStudioIdentity.set_image("
    assert_includes images, "RecordingStudioIdentity.remove_image("
    assert_includes images, "capability_action(name, api:)"
    assert_includes images, "reject_unknown: false"
  end

  def test_engine_registers_the_api_after_reload
    names = RecordingStudioIdentity::Engine.initializers.map(&:name)

    assert_includes names, "recording_studio_identity.api"
  end

  def test_does_not_fake_recording_studio_api
    Dir[File.expand_path("../lib/**/*.rb", __dir__)].each do |path|
      source = File.read(path)
      refute_includes source, "const_set", "#{path} must not fake constants"
      refute_includes source, "remove_const", "#{path} must not fake constants"
    end
  end
end
