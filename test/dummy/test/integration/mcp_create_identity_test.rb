# frozen_string_literal: true

require "test_helper"

class McpCreateIdentityTest < ActionDispatch::IntegrationTest
  setup do
    assert defined?(::RecordingStudioMcp), "dummy must load recording_studio_mcp"
    @previous_actor = Current.actor
    @owner = user("owner")
    Current.actor = @owner
    @workspace = owned_root(Workspace.create!(name: "MCP Workspace #{SecureRandom.hex(4)}"))
    @editor = user("editor")
    @editor_access = grant!(@workspace, @editor, :edit)
    @token, = token_for(@editor_access)
  end

  teardown { Current.actor = @previous_actor }

  test "a second create_identity on a one-slot parent is refused" do
    first = call_tool(
      "create_identity",
      parent_id: @workspace.id,
      kind: "person",
      name: "Ada Lovelace"
    )

    refute first.dig("result", "isError"), first.to_json
    first_id = first.dig("result", "structuredContent", "id")
    assert first_id.present?
    assert_equal first_id, RecordingStudioIdentity.identities(@workspace).sole.id

    second = call_tool(
      "create_identity",
      parent_id: @workspace.id,
      kind: "brand",
      name: "Other"
    )

    assert_equal true, second.dig("result", "isError"), second.to_json
    assert_includes second.dig("result", "content", 0, "text").to_s, "already the identity here"
    assert_equal first_id, RecordingStudioIdentity.identities(@workspace).sole.id
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
