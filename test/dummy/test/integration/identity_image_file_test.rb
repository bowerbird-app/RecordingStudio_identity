# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "stringio"
require "base64"

class IdentityImageFileTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TINY_PNG = Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
  ).freeze

  class MembersOnly
    def self.call(action:, actor:, recording:, role:)
      return false if actor.nil?

      RecordingStudioAccessible::Authorization.allowed?(actor: actor, recording: recording, role: role)
    end
  end

  setup do
    reach_attachment_file_without_a_sign_in_wall
    @user = User.create!(
      email: "image-file-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    Current.actor = @user
    @workspace = owned_root
    @identity = RecordingStudioIdentity.create(@workspace, actor: @user, kind: "brand", name: "Harbour Mark")
    RecordingStudioIdentity.set_image(@identity, signed_blob_id: issued_signed_id, actor: @user)
    @path = recording_studio_attachable.attachment_file_path(RecordingStudioIdentity.image(@identity))
    RecordingStudioIdentity.configuration.image_view_policy = nil
  end

  teardown do
    RecordingStudioIdentity.configuration.image_view_policy = nil
    Current.actor = nil
  end

  test "an anonymous request for the picture is denied when no policy is set" do
    get @path

    assert_picture_denied
  end

  test "a signed-in member can open the picture when no policy is set" do
    sign_in @user

    get @path

    assert_response :success
    assert_equal TINY_PNG, response.body
  end

  test "a policy that allows view serves the picture to an anonymous visitor and a member" do
    RecordingStudioIdentity.configuration.image_view_policy = lambda { |action:, actor:, recording:, role:|
      if action.to_sym == :view
        true
      else
        RecordingStudioAccessible::Authorization.allowed?(actor: actor, recording: recording, role: role)
      end
    }

    get @path

    assert_response :success
    assert_equal TINY_PNG, response.body

    sign_in @user

    get @path

    assert_response :success
    assert_equal TINY_PNG, response.body
  end

  test "a policy that denies view keeps the picture denied and still serves a member" do
    RecordingStudioIdentity.configuration.image_view_policy = MembersOnly

    get @path

    assert_picture_denied

    sign_in @user

    get @path

    assert_response :success
    assert_equal TINY_PNG, response.body
  end

  private

  def assert_picture_denied
    assert_response :redirect
    assert_equal "/", URI.parse(response.location).path
    refute_equal TINY_PNG, response.body
  end

  # The dummy signs every request in before it reaches a controller. The picture
  # route has to reach Attachable's :view check, which is what a public host does.
  def reach_attachment_file_without_a_sign_in_wall
    RecordingStudioAttachable::AttachmentsController.skip_before_action(
      :authenticate_user!, only: :file, raise: false
    )
  end

  def owned_root
    workspace = Workspace.create!(name: "Image #{SecureRandom.hex(4)}")
    root = RecordingStudio.create_root_recording!(workspace, actor: @user)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: @user)
    raise result.error if result.failure?

    root
  end

  def issued_signed_id
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(TINY_PNG),
      filename: "mark.png",
      content_type: "image/png",
      metadata: RecordingStudioAttachable::DirectUpload.metadata_for(recording: @identity, actor: @user)
    )
    blob.signed_id(purpose: RecordingStudioAttachable::DirectUpload::PURPOSE)
  end
end
