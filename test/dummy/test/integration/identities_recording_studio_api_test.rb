# frozen_string_literal: true

require "test_helper"
require "base64"
require "stringio"

class IdentitiesRecordingStudioApiTest < ActionDispatch::IntegrationTest
  BASE = "/recording_studio_api/api/v1"

  setup do
    @previous_actor = Current.actor
    @owner = user("owner")
    @editor = user("editor")
    @viewer = user("viewer")
    Current.actor = @owner
    @workspace = owned_root(Workspace.create!(name: "API Workspace #{SecureRandom.hex(4)}"))
    @agency = owned_root(Agency.create!(name: "API Agency #{SecureRandom.hex(4)}"))
    @stranger = user("stranger")
    @other = owned_root(Workspace.create!(name: "Other workspace #{SecureRandom.hex(4)}"), actor: @stranger)
    @editor_access = grant!(@workspace, @editor, :edit)
    @viewer_access = grant!(@workspace, @viewer, :view)
    @agency_editor_access = grant!(@agency, @editor, :edit)
    @editor_token, @editor_client = token_for(@editor_access)
    @viewer_token, = token_for(@viewer_access)
  end

  teardown { Current.actor = @previous_actor }

  test "index show create and update go through identity reads and writes" do
    listed = call(:get, "/identities", @editor_token, parent_id: @workspace.id)
    assert_response :success, response.body
    assert_equal [], listed.fetch("records")

    created = call(
      :post, "/identities", @editor_token,
      parent_id: @workspace.id, kind: "person", name: "Ada Lovelace"
    )
    assert_response :created, response.body
    assert_equal "Ada Lovelace", created.fetch("name")
    assert_equal "person", created.fetch("kind")
    assert_equal @workspace.id, created.fetch("parent_id")
    identity_id = created.fetch("id")
    assert_equal identity_id, RecordingStudioIdentity.identities(@workspace).sole.id

    shown = call(:get, "/identities/#{identity_id}", @editor_token)
    assert_response :success, response.body
    assert_equal "Ada Lovelace", shown.fetch("name")
    assert_equal identity_id, RecordingStudioIdentity.find(identity_id).id

    updated = call(:patch, "/identities/#{identity_id}", @editor_token, description: "Mathematician")
    assert_response :success, response.body
    assert_equal "Mathematician", updated.fetch("description")
    assert_equal "Mathematician", RecordingStudioIdentity.find(identity_id).recordable.description
  end

  test "set_image and remove_image are edit capability actions" do
    identity = RecordingStudioIdentity.create(@workspace, actor: @owner, kind: "person", name: "Ada")
    blob_id = signed_png_id(identity)

    set = call(:post, "/identities/#{identity.id}/actions/set_image", @editor_token, signed_blob_id: blob_id)
    assert_response :success, response.body
    assert RecordingStudioIdentity.image(identity.reload)

    removed = call(:post, "/identities/#{identity.id}/actions/remove_image", @editor_token)
    assert_response :success, response.body
    assert_nil RecordingStudioIdentity.image(identity.reload)
    assert_equal identity.id, removed.fetch("id")
  end

  test "view can read and is forbidden from writes" do
    identity = RecordingStudioIdentity.create(@workspace, actor: @owner, kind: "person", name: "Ada")

    call(:get, "/identities", @viewer_token, parent_id: @workspace.id)
    assert_response :success, response.body

    call(:get, "/identities/#{identity.id}", @viewer_token)
    assert_response :success, response.body

    call(:post, "/identities", @viewer_token, parent_id: @workspace.id, kind: "brand", name: "Other")
    assert_response :forbidden, response.body

    call(:patch, "/identities/#{identity.id}", @viewer_token, description: "Nope")
    assert_response :forbidden, response.body

    call(:post, "/identities/#{identity.id}/actions/set_image", @viewer_token, signed_blob_id: signed_png_id(identity))
    assert_response :forbidden, response.body

    call(:post, "/identities/#{identity.id}/actions/remove_image", @viewer_token)
    assert_response :forbidden, response.body
  end

  test "an identity in another workspace is not found" do
    stranger_identity = RecordingStudioIdentity.create(@other, actor: @stranger, kind: "person", name: "Elsewhere")

    call(:get, "/identities/#{stranger_identity.id}", @editor_token)
    assert_response :not_found, response.body

    call(:patch, "/identities/#{stranger_identity.id}", @editor_token, description: "Nope")
    assert_response :not_found, response.body

    call(:get, "/identities", @editor_token, parent_id: @other.id)
    assert_response :not_found, response.body
  end

  test "kind cannot change on update" do
    identity = RecordingStudioIdentity.create(@workspace, actor: @owner, kind: "person", name: "Ada")

    call(:patch, "/identities/#{identity.id}", @editor_token, kind: "brand", name: "Ada")
    assert_response :unprocessable_entity, response.body
    assert_equal "person", RecordingStudioIdentity.find(identity.id).recordable.kind
  end

  test "identity api registration matches ui roles and skips trash attach helpers" do
    registration = RecordingStudioApi.recordable_registration_for("RecordingStudioIdentity::Identity")
    assert_equal %i[create index show update], registration.operations
    assert_equal %w[remove_image set_image], registration.capability_actions
    assert_equal false, registration.auto_capability_actions
    assert_includes registration.immutable_fields, "kind"

    set_image = RecordingStudioApi.capability_action(:set_image)
    remove_image = RecordingStudioApi.capability_action(:remove_image)
    assert_equal :edit, set_image.required_role
    assert_equal :edit, remove_image.required_role
    assert_equal :attachable, set_image.capability
    assert_equal RecordingStudioIdentity::Api::IdentityResource::Index,
                 RecordingStudioApi.resource_handler("RecordingStudioIdentity::Identity", :index)
    assert_equal RecordingStudioIdentity::Identity::CREATE_FIELDS, RecordingStudioIdentity::Api::FIELDS
  end

  private

  def user(name)
    User.create!(
      email: "#{name}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end

  def owned_root(recordable, actor: @owner)
    root = RecordingStudio.root_recording_for(recordable)
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

  def call(method, path, token, params = {})
    send(method, "#{BASE}#{path}", params:, headers: {
      "Authorization" => "Bearer #{token}",
      "Accept" => "application/json"
    }, as: :json)
    response.media_type.to_s.include?("json") ? JSON.parse(response.body) : {}
  rescue JSON::ParserError
    {}
  end

  def signed_png_id(identity)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(TINY_PNG),
      filename: "portrait.png",
      content_type: "image/png",
      identify: false,
      metadata: RecordingStudioAttachable::DirectUpload.metadata_for(recording: identity, actor: @editor_client)
    )
    RecordingStudioAttachable::DirectUpload.sign(blob)
  end

  TINY_PNG = Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
  ).freeze
end
