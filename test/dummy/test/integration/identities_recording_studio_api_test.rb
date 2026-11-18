# frozen_string_literal: true

require "test_helper"
require "base64"
require "digest"
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

  test "identity_set_image and identity_remove_image are edit capability actions" do
    identity = RecordingStudioIdentity.create(@workspace, actor: @owner, kind: "person", name: "Ada")
    blob_id = signed_png_id(identity)

    set = call(:post, "/identities/#{identity.id}/actions/identity_set_image", @editor_token, signed_blob_id: blob_id)
    assert_response :success, response.body
    assert RecordingStudioIdentity.image(identity.reload)

    removed = call(:post, "/identities/#{identity.id}/actions/identity_remove_image", @editor_token)
    assert_response :success, response.body
    assert_nil RecordingStudioIdentity.image(identity.reload)
    assert_equal identity.id, removed.fetch("id")
  end

  test "index paginates identities with limit and pagination_token" do
    first = RecordingStudioIdentity.create(@agency, actor: @owner, kind: "person", name: "Ada")
    second = RecordingStudioIdentity.create(@agency, actor: @owner, kind: "brand", name: "Acme")
    expected_ids = [first.id, second.id].sort
    agency_token, = token_for(@agency_editor_access)

    page = call(:get, "/identities", agency_token, parent_id: @agency.id, limit: 1)
    assert_response :success, response.body
    seen = page.fetch("records").map { |record| record.fetch("id") }
    assert_equal 1, seen.size
    token = page.fetch("meta").fetch("next_pagination_token")
    assert token.present?

    while token.present?
      page = call(:get, "/identities", agency_token, parent_id: @agency.id, limit: 1, pagination_token: token)
      assert_response :success, response.body
      seen.concat(page.fetch("records").map { |record| record.fetch("id") })
      token = page.fetch("meta")["next_pagination_token"]
    end

    assert_equal expected_ids, seen.sort
    assert_equal expected_ids.size, seen.size
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

    call(
      :post, "/identities/#{identity.id}/actions/identity_set_image", @viewer_token,
      signed_blob_id: signed_png_id(identity)
    )
    assert_response :forbidden, response.body

    call(:post, "/identities/#{identity.id}/actions/identity_remove_image", @viewer_token)
    assert_response :forbidden, response.body

    call(:post, "/identities/#{identity.id}/actions/create_upload", @viewer_token, upload_fields(TINY_PNG))
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
    assert_equal %w[create_upload identity_remove_image identity_set_image], registration.capability_actions
    assert_equal false, registration.auto_capability_actions
    assert_includes registration.immutable_fields, "kind"

    set_image = RecordingStudioApi.capability_action(:identity_set_image)
    remove_image = RecordingStudioApi.capability_action(:identity_remove_image)
    assert_equal :edit, set_image.required_role
    assert_equal :edit, remove_image.required_role
    assert_equal :identity_image, set_image.capability
    assert_equal :identity_image, remove_image.capability
    assert_equal RecordingStudioIdentity::Api::IdentityResource::Index,
                 RecordingStudioApi.resource_handler("RecordingStudioIdentity::Identity", :index)
    assert_equal RecordingStudioIdentity::Identity::CREATE_FIELDS, RecordingStudioIdentity::Api::FIELDS
  end

  test "identity image docs name the upload, the recording id, and the Identity tag" do
    document = RecordingStudioApi::Services::OpenapiDocument.call
    set_image = image_operation(document, "identity_set_image")
    remove_image = image_operation(document, "identity_remove_image")
    stored_set = RecordingStudioApi.capability_action(:identity_set_image).openapi
    stored_remove = RecordingStudioApi.capability_action(:identity_remove_image).openapi

    assert_equal "Set image", stored_set[:title]
    assert_equal "Store or replace the one picture on this identity.", stored_set[:summary]
    assert_equal "The identity recording id. Create, list, and show return it as id.",
                 stored_set[:parameters].first[:description]
    assert_includes stored_set.dig(:responses, :"200", :description), "picture is not in this JSON"
    assert_equal "Set image", set_image[:title]
    assert_equal "Store or replace the one picture on this identity.", set_image[:summary]
    assert_includes set_image[:description], "Call create_upload on this identity first."
    assert_includes set_image[:description], "PUT the file bytes to upload.url with upload.headers"
    assert_includes set_image[:description], "image/*"
    assert_includes set_image[:description], "10 MB"
    assert_includes set_image[:description], "trashed identity is rejected"
    refute_includes set_image[:title], "Identity"
    refute_includes set_image[:summary], "Identity -"
    assert_equal ["Identity"], set_image[:tags]

    id_param = set_image[:parameters].find { |param| param["name"] == "id" }
    assert_equal "The identity recording id. Create, list, and show return it as id.", id_param["description"]
    refute_equal "Path parameter id.", id_param["description"]
    refute_equal "Resource identifier.", id_param["description"]

    blob = set_image.dig(:requestBody, :content, "application/json", :schema, :properties, "signed_blob_id")
    assert_includes blob[:description], "create_upload on this identity"
    assert_includes set_image.dig(:responses, "200", "description"), "picture is not in this JSON"

    assert_equal "Remove image", stored_remove[:title]
    assert_equal "Remove the picture from this identity.", stored_remove[:summary]
    assert_equal "Remove image", remove_image[:title]
    assert_equal "Remove the picture from this identity.", remove_image[:summary]
    assert_includes remove_image[:description], "changes nothing"
    assert_includes remove_image[:description], "already trashed"
    refute_includes remove_image[:title], "Identity"
    refute_includes remove_image[:summary], "Identity -"

    identity_group = document[:"x-tagGroups"].find { |group| group[:name] == "Identity" }
    assert_includes identity_group[:tags], "Identity"
    identity_tag = document[:tags].find { |tag| tag[:name] == "Identity" }
    assert_equal "A public identity for a person, company, brand, or organisation. The id is the recording id.",
                 identity_tag[:description]
    registration = RecordingStudioApi.recordable_registration_for("RecordingStudioIdentity::Identity")
    assert_equal ["Identity"], registration.openapi[:tags]
    assert_equal "Identity", registration.openapi.dig(:tag, :group)

    upload = image_operation(document, "create_upload")
    stored_upload = RecordingStudioApi.capability_action(:create_upload).openapi_for(
      type: "RecordingStudioIdentity::Identity"
    )
    assert_equal "Upload identity picture", stored_upload[:title]
    assert_equal "Prepare an upload for this identity's picture.", stored_upload[:summary]
    assert_equal "Upload identity picture", upload[:title]
    assert_equal "Prepare an upload for this identity's picture.", upload[:summary]
    assert_includes upload[:description], "The path id is the identity recording id"
    assert_includes upload[:description], "filename, byte_size, checksum, and content_type"
    assert_includes upload[:description], "MD5, Base64-encoded"
    assert_includes upload[:description], "signed_blob_id, upload.url, upload.headers, and expires_at"
    assert_includes upload[:description], "image/*"
    assert_includes upload[:description], "10 MB"
    assert_includes upload[:description], "5 minutes"
    assert_includes upload[:description], "same actor"
    refute_includes upload[:title], "Identity"
    assert_equal ["Identity"], upload[:tags]
    upload_id = upload[:parameters].find { |param| param["name"] == "id" }
    assert upload_id["description"].present?
    refute_equal "Path parameter id.", upload_id["description"]
  end

  test "create_upload then set_image stores the picture" do
    identity = RecordingStudioIdentity.create(@workspace, actor: @owner, kind: "person", name: "Ada")
    bytes = TINY_PNG
    ticket = call(:post, "/identities/#{identity.id}/actions/create_upload", @editor_token, upload_fields(bytes))
    assert_response :success, response.body
    signed_blob_id = ticket.fetch("signed_blob_id")
    url = ticket.fetch("upload").fetch("url")
    headers = ticket.fetch("upload").fetch("headers")
    assert ticket.fetch("expires_at").present?

    put_bytes(url, bytes, headers)
    assert_includes [200, 204], response.status

    set = call(
      :post, "/identities/#{identity.id}/actions/identity_set_image", @editor_token,
      signed_blob_id: signed_blob_id
    )
    assert_response :success, response.body
    assert_equal identity.id, set.fetch("id")
    image = RecordingStudioIdentity.image(identity.reload)
    assert image
    assert_equal "portrait.png", image.recordable.file.blob.filename.to_s
  end

  test "identity image actions do not leak onto other attachable api types" do
    unless RecordingStudio.capability_enabled?(:attachable, for: "Page")
      RecordingStudio.enable_capability(:attachable, on: Page)
    end
    unless RecordingStudioApi.recordable_registration_for("Page")
      RecordingStudioApi.register_recordable_type_api(
        "Page",
        operations: %i[index show],
        serializer: ->(page, **) { { title: page.title } },
        output_keys: %i[title]
      )
    end

    assert RecordingStudio.capability_enabled?(:attachable, for: "Page")
    assert RecordingStudioApi.recordable_registration_for("Page")
    page_actions = RecordingStudioApi.capability_actions_for("Page").map(&:name)
    refute_includes page_actions, "identity_set_image"
    refute_includes page_actions, "identity_remove_image"
  end

  private

  def image_operation(document, action_name)
    _path, verbs = document[:paths].find do |path, _verbs|
      path.include?("/identities/") && path.end_with?("/actions/#{action_name}")
    end
    verbs.fetch("post")
  end

  def upload_fields(bytes)
    {
      filename: "portrait.png",
      byte_size: bytes.bytesize,
      checksum: Base64.strict_encode64(Digest::MD5.digest(bytes)),
      content_type: "image/png"
    }
  end

  def put_bytes(url, bytes, headers)
    uri = URI.parse(url)
    put uri.request_uri, params: bytes, headers: headers.transform_keys(&:to_s)
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
