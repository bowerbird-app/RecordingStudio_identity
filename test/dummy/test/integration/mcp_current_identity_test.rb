# frozen_string_literal: true

require "test_helper"

class McpCurrentIdentityTest < ActionDispatch::IntegrationTest
  setup do
    assert defined?(::RecordingStudioMcp), "dummy must load recording_studio_mcp"
    @previous_actor = Current.actor
    @owner = user("owner")
    Current.actor = @owner
    @workspace = owned_root(Workspace.create!(name: "Current #{SecureRandom.hex(4)}"))
    @other = owned_root(Workspace.create!(name: "Other #{SecureRandom.hex(4)}"))
    @editor = user("editor")
    @editor_access = grant!(@workspace, @editor, :edit)
    @token, = token_for(@editor_access)
  end

  teardown { Current.actor = @previous_actor }

  test "show and update use this client's root" do
    identity = RecordingStudioIdentity.create(@workspace, actor: @owner, kind: "person", name: "Ada")
    other = RecordingStudioIdentity.create(@other, actor: @owner, kind: "brand", name: "Other Brand")
    recordable_id = identity.recordable_id

    shown = call_tool("show_current_identity")

    refute shown.dig("result", "isError"), shown.to_json
    assert_equal identity.id, shown.dig("result", "structuredContent", "id")
    assert_equal "Ada", shown.dig("result", "structuredContent", "name")
    assert_equal "person", shown.dig("result", "structuredContent", "kind")

    updated = call_tool("update_current_identity", name: "Ada Lovelace", description: "Mathematician")

    refute updated.dig("result", "isError"), updated.to_json
    assert_equal identity.id, updated.dig("result", "structuredContent", "id")
    assert_equal "Ada Lovelace", updated.dig("result", "structuredContent", "name")
    assert_equal "Mathematician", updated.dig("result", "structuredContent", "description")
    assert_equal "person", updated.dig("result", "structuredContent", "kind")
    identity.reload
    assert_equal "Ada Lovelace", identity.recordable.name
    refute_equal recordable_id, identity.recordable_id
    assert_equal "Other Brand", other.reload.recordable.name

    again = identity.recordable_id
    repeat = call_tool("update_current_identity", name: "Ada Lovelace", description: "Mathematician")

    refute repeat.dig("result", "isError"), repeat.to_json
    assert_equal again, identity.reload.recordable_id
  end

  test "an id for another root is refused" do
    identity = RecordingStudioIdentity.create(@workspace, actor: @owner, kind: "person", name: "Ada")
    other = RecordingStudioIdentity.create(@other, actor: @owner, kind: "brand", name: "Other Brand")

    shown = call_tool("show_current_identity", id: other.id)
    updated = call_tool("update_current_identity", id: other.id, name: "Hijack")

    assert_equal true, shown.dig("result", "isError"), shown.to_json
    assert_equal true, updated.dig("result", "isError"), updated.to_json
    assert_equal "Ada", identity.reload.recordable.name
    assert_equal "Other Brand", other.reload.recordable.name
    assert_equal identity.id, call_tool("show_current_identity").dig("result", "structuredContent", "id")
  end

  test "a root with no identity is an error" do
    shown = call_tool("show_current_identity")
    updated = call_tool("update_current_identity", name: "Guess")

    assert_equal true, shown.dig("result", "isError"), shown.to_json
    assert_includes shown.dig("result", "content", 0, "text").to_s, "no identity"
    assert_equal true, updated.dig("result", "isError"), updated.to_json
    assert_includes updated.dig("result", "content", 0, "text").to_s, "no identity"
    assert_empty RecordingStudioIdentity.identities(@workspace)
    assert_empty RecordingStudioIdentity.identities(@other)
  end

  test "a root that allows many identities is an error" do
    agency = owned_root(Agency.create!(name: "Agency #{SecureRandom.hex(4)}"))
    kept = RecordingStudioIdentity.create(agency, actor: @owner, kind: "brand", name: "Northwind")
    access = grant!(agency, @editor, :edit)
    @token, = token_for(access)

    shown = call_tool("show_current_identity")
    updated = call_tool("update_current_identity", name: "Guess")

    assert_equal true, shown.dig("result", "isError"), shown.to_json
    assert_includes shown.dig("result", "content", 0, "text").to_s, "allows many identities"
    assert_equal true, updated.dig("result", "isError"), updated.to_json
    assert_includes updated.dig("result", "content", 0, "text").to_s, "allows many identities"
    assert_equal "Northwind", kept.reload.recordable.name
    assert_equal [kept.id], RecordingStudioIdentity.identities(agency).map(&:id)
  end

  test "kind cannot change on the current identity" do
    identity = RecordingStudioIdentity.create(@workspace, actor: @owner, kind: "person", name: "Ada")

    updated = call_tool("update_current_identity", kind: "brand", name: "Ada")

    assert_equal true, updated.dig("result", "isError"), updated.to_json
    assert_includes updated.dig("result", "content", 0, "text").to_s, "kind"
    assert_equal "person", identity.reload.recordable.kind
    assert_equal "Ada", identity.recordable.name
  end

  private

  def call_tool(name, **arguments)
    post "/recording_studio_mcp",
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "tools/call",
           params: { name: name, arguments: arguments }
         }.to_json,
         headers: {
           "Content-Type" => "application/json",
           "Accept" => "application/json",
           "Authorization" => "Bearer #{@token}"
         }

    assert_response :success, response.body
    JSON.parse(response.body)
  end

  def user(name)
    User.create!(
      email: "#{name}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end

  def owned_root(recordable, actor: @owner)
    root = RecordingStudio.create_root_recording!(recordable, actor: actor)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor:)
    raise result.error if result.failure?

    root
  end

  def grant!(recording, actor, role)
    result = RecordingStudioAccessible.grant_access(recording:, actor:, role:, manager_actor: @owner)
    raise result.error if result.failure?

    result.value
  end

  def token_for(access_recording)
    provision = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_recording.parent_recording || access_recording.root_recording,
      manager_actor: @owner,
      role: access_recording.recordable.role,
      name: "Client #{SecureRandom.hex(3)}"
    )
    raise provision.error unless provision.success?

    issued = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: provision.value.fetch(:credential).oauth_client_id,
      client_secret: provision.value.fetch(:token)
    )
    raise issued.error unless issued.success?

    [issued.value.fetch(:access_token), provision.value.fetch(:api_client)]
  end
end
