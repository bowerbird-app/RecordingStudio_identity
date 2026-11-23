# frozen_string_literal: true

require "test_helper"

class McpCopyTest < Minitest::Test
  FROZEN_TOOL_NAMES = %w[
    create_identity
    identity_remove_image
    identity_set_image
    list_identities
    show_identity
    update_identity
  ].freeze

  def test_tool_names_are_the_named_identity_set
    names = RecordingStudioIdentity::McpCopy.tool_names

    assert_equal FROZEN_TOOL_NAMES, names.sort
    refute_includes names, "create_upload"
    refute_includes names, "delete_identity"
    refute_includes names, "destroy_identity"
  end

  def test_update_copy_omits_kind_and_delete
    update = RecordingStudioIdentity::McpCopy::CRUD_COPY.fetch(:update)
    create = RecordingStudioIdentity::McpCopy::CRUD_COPY.fetch(:create)

    assert_equal %w[description name website_url], update.fetch(:input).keys.sort
    assert_includes create.fetch(:input).keys, "kind"
    refute_includes update.fetch(:description), "Access"
    refute_includes update.fetch(:description), "Accessible"
    refute_includes RecordingStudioIdentity::McpCopy::TYPE_DESCRIPTION, "Access"
    assert_includes create.fetch(:description), "already has an identity"
    assert_includes RecordingStudioIdentity::McpCopy::TYPE_DESCRIPTION, "invited signup"
    assert_includes RecordingStudioIdentity::McpCopy::TYPE_DESCRIPTION, "parent_id"
  end

  def test_register_does_not_raise_when_mcp_is_missing
    skip if defined?(::RecordingStudioMcp)

    RecordingStudioIdentity::McpCopy.register!
  end

  def test_engine_registers_mcp_after_api
    names = RecordingStudioIdentity::Engine.initializers.map(&:name)

    assert_includes names, "recording_studio_identity.mcp"
    api_index = names.index("recording_studio_identity.api")
    mcp_index = names.index("recording_studio_identity.mcp")
    assert api_index < mcp_index
  end

  def test_create_tool_does_not_bypass_identity_create
    resource = File.read(File.expand_path("../lib/recording_studio_identity/api/identity_resource.rb", __dir__))
    mcp = File.read(File.expand_path("../lib/recording_studio_identity/mcp_copy.rb", __dir__))

    assert_includes resource, "RecordingStudioIdentity.create("
    refute_includes mcp, "RecordingStudio.record!"
    refute_includes mcp, "Identity.new"
  end
end
