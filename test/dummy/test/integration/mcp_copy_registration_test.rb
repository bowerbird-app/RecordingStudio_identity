# frozen_string_literal: true

require "test_helper"

class McpCopyRegistrationTest < ActionDispatch::IntegrationTest
  FROZEN_TOOL_NAMES = %w[
    create_identity
    identity_remove_image
    identity_set_image
    list_identities
    show_current_identity
    show_identity
    update_current_identity
    update_identity
  ].freeze

  setup do
    assert defined?(::RecordingStudioMcp), "dummy must load recording_studio_mcp"
  end

  test "boot registers the identity type paragraph" do
    registered = RecordingStudioMcp.configuration.type(RecordingStudioIdentity::Api::TYPE)

    assert registered, "missing MCP type RecordingStudioIdentity::Identity"
    assert_equal RecordingStudioIdentity::McpCopy::TYPE_DESCRIPTION, registered.description
    refute_includes registered.description, "Access"
    refute_includes registered.description, "Accessible"
  end

  test "boot registers named identity tools on public and operations" do
    names = RecordingStudioIdentity::McpCopy.tool_names

    assert_equal FROZEN_TOOL_NAMES, names.sort
    refute_includes names, "create_upload"

    public_server = RecordingStudioMcp.configuration.servers.fetch("public")
    operations_server = RecordingStudioMcp.configuration.servers.fetch("operations")
    public_names = public_server.included_tools.map(&:name)
    operations_names = operations_server.included_tools.map(&:name)

    assert_equal :public, public_server.api
    assert_equal :operations, operations_server.api
    names.each do |name|
      assert_includes public_names, name
      assert_includes operations_names, name
    end
    refute_includes public_names, "create_upload"
    refute_includes operations_names, "create_upload"
  end

  test "named crud tools bind the api operation and omit kind on update" do
    RecordingStudioIdentity::McpCopy::CRUD_OPERATIONS.each do |name, api_operation|
      tool = RecordingStudioMcp.configuration.tool(RecordingStudioIdentity::McpCopy.tool_name(name))
      copy = RecordingStudioIdentity::McpCopy::CRUD_COPY.fetch(name)

      assert tool, "missing MCP tool #{name}"
      assert_equal RecordingStudioIdentity::Api::TYPE, tool.type
      assert_equal :operation, tool.target.kind
      assert_equal api_operation, tool.target.value
      assert_equal copy.fetch(:title), tool.title
      assert_equal copy.fetch(:description), tool.description
      assert_equal copy.fetch(:input), tool.input
      assert_equal copy.fetch(:output), tool.output
    end

    update = RecordingStudioMcp.configuration.tool("update_identity")
    refute update.input.key?("kind")
  end

  test "current identity tools bind the root endpoints and omit id" do
    RecordingStudioIdentity::McpCopy::CURRENT.each do |name|
      tool = RecordingStudioMcp.configuration.tool(RecordingStudioIdentity::McpCopy.tool_name(name))
      copy = RecordingStudioIdentity::McpCopy::CurrentCopy::CURRENT_COPY.fetch(name)

      assert tool, "missing MCP tool #{name}"
      assert_nil tool.type
      assert_equal :endpoint, tool.target.kind
      assert_equal name, tool.target.value
      assert_equal copy.fetch(:title), tool.title
      assert_equal copy.fetch(:description), tool.description
      assert_equal copy.fetch(:input), tool.input
      assert_equal copy.fetch(:output), tool.output
      refute tool.input.key?("id")
      refute tool.input.key?("parent_id")
      refute tool.input.key?("kind")
    end

    %i[public operations].each do |api|
      show = RecordingStudioApi.registered_endpoint(:show_current_identity, api: api)
      update = RecordingStudioApi.registered_endpoint(:update_current_identity, api: api)

      assert_equal :get, show.http_verb
      assert_equal :patch, update.http_verb
      assert_equal "current_identity", show.path
      assert_equal "current_identity", update.path
      assert_equal ["Identity"], show.openapi_tags
    end
  end

  test "current identity docs tag follows the host setting" do
    configuration = RecordingStudioIdentity.configuration
    previous = configuration.current_identity_tag
    configuration.current_identity_tag = "Workspace"
    surface = RecordingStudioMcp::ToolSurface.for(api: :public)

    %w[show_current_identity update_current_identity].each do |name|
      endpoint = RecordingStudioApi.registered_endpoint(name, api: :public)
      entry = surface.tool_entries.find { |item| item.definition[:name] == name }

      assert_equal ["Workspace"], endpoint.openapi_tags
      assert_equal ["Workspace"], RecordingStudioMcp::ToolDocs.tags_for_entry(entry, api: :public)
    end

    identity = surface.tool_entries.find { |item| item.definition[:name] == "show_identity" }
    assert_equal ["Identity"], RecordingStudioMcp::ToolDocs.tags_for_entry(identity, api: :public)
  ensure
    configuration.current_identity_tag = previous
  end

  test "named image tools bind the identity image actions" do
    RecordingStudioIdentity::McpCopy::ACTIONS.each do |action|
      tool = RecordingStudioMcp.configuration.tool(RecordingStudioIdentity::McpCopy.tool_name(action))
      copy = RecordingStudioIdentity::McpCopy::ACTION_COPY.fetch(action)

      assert tool, "missing MCP tool #{action}"
      assert_equal RecordingStudioIdentity::Api::TYPE, tool.type
      assert_equal :action, tool.target.kind
      assert_equal action, tool.target.value
      assert_equal copy.fetch(:title), tool.title
      assert_equal copy.fetch(:description), tool.description
      assert_equal copy.fetch(:input), tool.input
      assert_equal copy.fetch(:output), tool.output
      refute_includes tool.description, "Access"
    end
  end

  test "identity is registered on public and operations apis" do
    %i[public operations].each do |api|
      registration = RecordingStudioApi.recordable_registration_for(
        RecordingStudioIdentity::Api::TYPE, api: api
      )

      assert registration, "missing identity API on #{api}"
      assert_equal %i[create index show update], registration.operations.sort
      refute_includes registration.operations, :destroy
      assert_includes registration.immutable_fields, "kind"
      assert_includes registration.capability_actions, "identity_set_image"
      assert_includes registration.capability_actions, "identity_remove_image"
      assert_includes registration.capability_actions, "create_upload"
    end
  end

  test "dummy lists site setting among recordable types" do
    types = RecordingStudio.configuration.recordable_types.map(&:to_s)

    assert_includes types, "RecordingStudioSiteSettings::SiteSetting"
    assert RecordingStudio.validate_recordable_declarations!
  end

  test "register twice leaves the same registry" do
    before = registry_snapshot
    RecordingStudioIdentity::McpCopy.register!
    RecordingStudioIdentity::McpCopy.register!

    assert_equal before, registry_snapshot
  end

  def registry_snapshot
    names = RecordingStudioIdentity::McpCopy.tool_names
    {
      tool_keys: RecordingStudioMcp.configuration.tools.keys.sort,
      type_keys: RecordingStudioMcp.configuration.types.keys.sort,
      identity: names.map do |name|
        tool = RecordingStudioMcp.configuration.tool(name)
        [name, tool&.title, tool&.description, tool&.type, tool&.target]
      end
    }
  end
end
