# frozen_string_literal: true

require "test_helper"

class McpCopyTest < Minitest::Test
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
    assert_includes create.fetch(:description), "allow: :one"
    assert_includes create.fetch(:description), "allow: :many"
    refute_includes RecordingStudioIdentity::McpCopy::TYPE_DESCRIPTION, "signup"
    refute_includes RecordingStudioIdentity::McpCopy::TYPE_DESCRIPTION, "invited"
    refute_includes RecordingStudioIdentity::McpCopy::TYPE_DESCRIPTION, "stays in sync"
    assert_includes RecordingStudioIdentity::McpCopy::TYPE_DESCRIPTION, "parent_id"
    assert_includes RecordingStudioIdentity::McpCopy::TYPE_DESCRIPTION, "allow: :one"
    assert_includes RecordingStudioIdentity::McpCopy::TYPE_DESCRIPTION, "for example a press center"
    refute_includes RecordingStudioIdentity::McpCopy::TYPE_DESCRIPTION, "or workspace"
    assert_includes RecordingStudioIdentity::McpCopy::TYPE_DESCRIPTION, "allow: :many"
  end

  def test_current_identity_copy_takes_no_id_and_rejects_kind
    show = RecordingStudioIdentity::McpCopy::CurrentCopy::CURRENT_COPY.fetch(:show_current_identity)
    update = RecordingStudioIdentity::McpCopy::CurrentCopy::CURRENT_COPY.fetch(:update_current_identity)

    assert_equal "show_current_identity", RecordingStudioIdentity::McpCopy.tool_name(:show_current_identity)
    assert_equal "update_current_identity", RecordingStudioIdentity::McpCopy.tool_name(:update_current_identity)
    assert_empty show.fetch(:input)
    assert_equal %w[description name website_url], update.fetch(:input).keys.sort
    assert_includes show.fetch(:description), "no id"
    assert_includes show.fetch(:description), "no parent_id"
    assert_includes show.fetch(:description), "allow: :many"
    assert_includes update.fetch(:description), "kind cannot change"
    assert_includes update.fetch(:description), "at the root"
    assert_equal "The identity on this root.", show.fetch(:output)
    assert_equal "The identity after the change.", update.fetch(:output)
    refute_includes show.fetch(:description), "Access"
    refute_includes update.fetch(:description), "Access"
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

  def test_image_copy_reuses_openapi_fragments_without_edit_access
    set = RecordingStudioIdentity::McpCopy::ACTION_COPY.fetch(:identity_set_image)
    remove = RecordingStudioIdentity::McpCopy::ACTION_COPY.fetch(:identity_remove_image)
    openapi_set = RecordingStudioIdentity::Api::ImageActionCopy::SET_IMAGE_DESCRIPTION
    openapi_remove = RecordingStudioIdentity::Api::ImageActionCopy::REMOVE_IMAGE_DESCRIPTION

    assert_includes set.fetch(:description), RecordingStudioIdentity::Api::ImageActionCopy::PUT_THEN_PASS_SIGNED_BLOB
    assert_includes set.fetch(:description), RecordingStudioIdentity::Api::ImageActionCopy::SIGNED_ID_REJECTED
    assert_includes set.fetch(:description), RecordingStudioIdentity::Api::ImageActionCopy::TRASHED_IDENTITY_REJECTED
    refute_includes set.fetch(:description), RecordingStudioIdentity::Api::ImageActionCopy::NEEDS_EDIT_ACCESS
    assert_includes remove.fetch(:description), RecordingStudioIdentity::Api::ImageActionCopy::REMOVE_KEEPS_FIELDS
    assert_includes remove.fetch(:description), RecordingStudioIdentity::Api::ImageActionCopy::REMOVE_NO_PICTURE
    refute_includes remove.fetch(:description), RecordingStudioIdentity::Api::ImageActionCopy::NEEDS_EDIT_ACCESS
    assert_includes openapi_set, RecordingStudioIdentity::Api::ImageActionCopy::NEEDS_EDIT_ACCESS
    assert_includes openapi_remove, RecordingStudioIdentity::Api::ImageActionCopy::NEEDS_EDIT_ACCESS
    assert_equal(
      "The picture is the one Attachable image on this identity, stored under the name image. " \
      "Use this to store the first picture or replace the current one. " \
      "Call create_upload on this identity first. " \
      "It returns signed_blob_id, upload.url, and upload.headers. " \
      "PUT the file bytes to upload.url with upload.headers, then pass signed_blob_id here. " \
      "A signed id from another recording or another actor is rejected. " \
      "Needs edit access. A trashed identity is rejected. " \
      "Allowed files are image types (image/*), up to 10 MB. An identity holds one picture. " \
      "Replacing revises that attachment recording and restores it when it was trashed.",
      openapi_set
    )
    assert_equal(
      "Removes the picture from this identity. The name, kind, description, and website URL stay. " \
      "Needs edit access. A trashed identity is rejected. " \
      "If there is no picture, or that picture is already trashed, the call succeeds and changes nothing. " \
      "Otherwise the attachment is trashed. This API does not restore it. " \
      "A later set image revises that same attachment.",
      openapi_remove
    )
  end

  def test_create_tool_does_not_bypass_identity_create
    resource = File.read(File.expand_path("../lib/recording_studio_identity/api/identity_resource.rb", __dir__))
    mcp = File.read(File.expand_path("../lib/recording_studio_identity/mcp_copy.rb", __dir__))

    assert_includes resource, "RecordingStudioIdentity.create("
    refute_includes mcp, "RecordingStudio.record!"
    refute_includes mcp, "Identity.new"
  end
end
