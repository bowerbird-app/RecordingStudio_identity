# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "stringio"

class IdentityReturnToTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load_seeds
    @user = User.find_by!(email: "admin@admin.com")
    sign_in @user
    @studio = RecordingStudio::Recording.find_by!(recordable: Workspace.find_by!(name: "Studio Workspace"))
    @agency = RecordingStudio::Recording.find_by!(recordable: Agency.find_by!(name: "Harbour Agency"))
  end

  test "create carries return_to from the kind chooser through save" do
    get new_identity_path(@agency, return_to: "/welcome")

    assert_response :success
    assert_hidden_return_to "/welcome"
    assert_select "nav.flat-pack-page-nav a[aria-label=Back][href='/welcome']"
    assert_select "nav.flat-pack-page-nav a[aria-label=Close][href='/welcome']"

    get new_identity_path(@agency, kind: "brand", return_to: "/welcome")

    assert_response :success
    assert_hidden_return_to "/welcome"
    assert_cancel_to "/welcome"
    assert_select "nav.flat-pack-page-nav a[aria-label=Back][href='/welcome']"
    assert_select "nav.flat-pack-page-nav a[aria-label=Close][href='/welcome']"
    key = css_select("input[name='idempotency_key']").first["value"]

    assert_difference -> { RecordingStudioIdentity.identities(@agency).size }, 1 do
      post recording_studio_identity.recording_identities_path(@agency), params: {
        idempotency_key: key,
        return_to: "/welcome?step=2",
        identity: { kind: "brand", name: "Harbour Return", description: "", website_url: "" }
      }
    end

    assert_redirected_to "/welcome?step=2"
    created = RecordingStudioIdentity.identities(@agency).find { |identity| identity.recordable.name == "Harbour Return" }
    assert created
  end

  test "one category skips the chooser and still keeps return_to" do
    with_categories(person: { label: "Person" }) do
      get new_identity_path(@agency, return_to: "/welcome")

      assert_response :success
      assert_includes response.body, "Name"
      refute_includes response.body, "Who is this press profile for?"
      assert_hidden_return_to "/welcome"
      assert_cancel_to "/welcome"
      assert_select "nav.flat-pack-page-nav a[href='/welcome']"
    end
  end

  test "a failed create stays on the form and keeps return_to" do
    post recording_studio_identity.recording_identities_path(@agency), params: {
      idempotency_key: SecureRandom.uuid,
      return_to: "/welcome",
      identity: { kind: "brand", name: "" }
    }

    assert_response :unprocessable_content
    assert_hidden_return_to "/welcome"
    assert_cancel_to "/welcome"
  end

  test "a rejected image on create returns to the form with return_to" do
    assert_no_difference -> { RecordingStudioIdentity.identities(@agency).size } do
      post recording_studio_identity.recording_identities_path(@agency), params: {
        idempotency_key: SecureRandom.uuid,
        return_to: "/welcome",
        identity: { kind: "brand", name: "Bad Picture", description: "", website_url: "" },
        image: { signed_blob_id: "not-a-real-blob" }
      }
    end

    assert_redirected_to new_identity_path(@agency, return_to: "/welcome")
  end

  test "update carries return_to from the edit form through save" do
    identity = RecordingStudioIdentity.identity(@studio)

    get recording_studio_identity.edit_identity_path(identity, return_to: "/welcome")

    assert_response :success
    assert_hidden_return_to "/welcome"
    assert_cancel_to "/welcome"
    assert_select "nav.flat-pack-page-nav a[aria-label=Back][href='/welcome']"
    assert_select "nav.flat-pack-page-nav a[aria-label=Close][href='/welcome']"

    patch recording_studio_identity.identity_path(identity), params: {
      return_to: "/welcome",
      identity: { name: "Sarah Jones Studio", description: "Photographer and creator", website_url: "https://example.com" }
    }

    assert_redirected_to "/welcome"
    assert_equal "Sarah Jones Studio", identity.reload.recordable.name
  end

  test "a failed update stays on the form and keeps return_to" do
    identity = RecordingStudioIdentity.identity(@studio)

    patch recording_studio_identity.identity_path(identity), params: {
      return_to: "/welcome",
      identity: { name: "", website_url: "https://example.com" }
    }

    assert_response :unprocessable_content
    assert_hidden_return_to "/welcome"
    assert_cancel_to "/welcome"
  end

  test "a rejected image on update returns to edit with return_to" do
    identity = RecordingStudioIdentity.identity(@studio)

    patch recording_studio_identity.identity_path(identity), params: {
      return_to: "/welcome",
      identity: { name: "Sarah Jones", description: "Photographer and creator", website_url: "https://example.com" },
      image: { signed_blob_id: "not-a-real-blob" }
    }

    assert_redirected_to recording_studio_identity.edit_identity_path(identity, return_to: "/welcome")
  end

  test "unsafe return paths are ignored" do
    identity = RecordingStudioIdentity.identity(@studio)
    unsafe = [
      "https://evil.example/phish",
      "//evil.example/phish",
      "/\\evil.example",
      "javascript:alert(1)",
      "https://www.example.com/onboarding"
    ]

    unsafe.each do |path|
      get new_identity_path(@agency, return_to: path)

      assert_response :success
      assert_select "input[name=return_to]", count: 0
      assert_select "a[href=?]", path, count: 0
    end

    get recording_studio_identity.edit_identity_path(identity, return_to: "https://evil.example/phish")

    assert_response :success
    assert_select "input[name=return_to]", count: 0
    assert_select "a[href=?]", "https://evil.example/phish", count: 0
    assert_cancel_to recording_studio_identity.identity_path(identity)

    assert_difference -> { RecordingStudioIdentity.identities(@agency).size }, 1 do
      post recording_studio_identity.recording_identities_path(@agency), params: {
        idempotency_key: SecureRandom.uuid,
        return_to: "https://evil.example/phish",
        identity: { kind: "brand", name: "Ignored Return", description: "", website_url: "" }
      }
    end

    assert_response :see_other
    refute_includes response.headers["Location"], "evil.example"
    created = RecordingStudioIdentity.identities(@agency).find { |recording| recording.recordable.name == "Ignored Return" }
    assert_redirected_to recording_studio_identity.identity_path(created)

    patch recording_studio_identity.identity_path(identity), params: {
      return_to: "//evil.example/phish",
      identity: { name: "Sarah Jones", description: "Photographer and creator", website_url: "https://example.com" }
    }

    assert_redirected_to recording_studio_identity.identity_path(identity)
  end

  test "a host hook can reject an otherwise safe return path" do
    identity = RecordingStudioIdentity.identity(@studio)
    configuration = RecordingStudioIdentity.configuration
    previous = configuration.allow_return_to
    configuration.allow_return_to = ->(path) { path == "/welcome" }

    patch recording_studio_identity.identity_path(identity), params: {
      return_to: "/elsewhere",
      identity: { name: "Sarah Jones", description: "Photographer and creator", website_url: "https://example.com" }
    }
    assert_redirected_to recording_studio_identity.identity_path(identity)

    patch recording_studio_identity.identity_path(identity), params: {
      return_to: "/welcome",
      identity: { name: "Sarah Jones", description: "Photographer and creator", website_url: "https://example.com" }
    }
    assert_redirected_to "/welcome"
  ensure
    configuration.allow_return_to = previous
  end

  test "an unknown kind keeps a safe return path on the chooser" do
    get new_identity_path(@agency, kind: "mascot", return_to: "/welcome")

    assert_response :success
    assert_includes response.body, "Choose one of the configured categories."
    assert_hidden_return_to "/welcome"
    assert_select "nav.flat-pack-page-nav a[href='/welcome']"
  end

  private

  def new_identity_path(recording, **params)
    recording_studio_identity.new_recording_identity_path(recording, **params)
  end

  def assert_hidden_return_to(path)
    assert_select "input[type=hidden][name=return_to][value=?]", path
  end

  def assert_cancel_to(path)
    assert_select "a[href=?]", path, text: "Cancel"
  end

  def load_seeds
    previous = $stdout
    $stdout = StringIO.new
    load Rails.root.join("db/seeds.rb").to_s
  ensure
    $stdout = previous
  end

  def with_categories(definitions)
    configuration = RecordingStudioIdentity.configuration
    previous = configuration.categories
    configuration.types = definitions
    yield
  ensure
    configuration.instance_variable_set(:@categories, previous)
  end
end
