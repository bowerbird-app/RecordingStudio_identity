# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "stringio"

class IdentitiesFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load_seeds
    @user = User.find_by!(email: "admin@admin.com")
    sign_in @user
    @studio = RecordingStudio::Recording.find_by!(recordable: Workspace.find_by!(name: "Studio Workspace"))
    @agency = RecordingStudio::Recording.find_by!(recordable: Agency.find_by!(name: "Harbour Agency"))
    @project = RecordingStudio::Recording.find_by!(recordable: Project.find_by!(name: "Harbour fit-out"))
  end

  test "home links the four identity examples" do
    get root_path

    assert_response :success
    assert_includes response.body, "One identity"
    assert_includes response.body, "Many identities"
    assert_includes response.body, "Nested parent"
    assert_includes response.body, "Creation text"
  end

  test "many index lists identities and one index shows the occupant" do
    get recording_studio_identity.recording_identities_path(@agency)

    assert_response :success
    assert_includes response.body, "Northwind"
    assert_includes response.body, "Dove"
    assert_includes response.body, "+ Identity"

    get recording_studio_identity.recording_identities_path(@studio)

    assert_response :success
    assert_includes response.body, "Sarah Jones"
    refute_includes response.body, "+ Identity"
  end

  test "category selection uses configured copy and company field labels" do
    get recording_studio_identity.new_recording_identity_path(@agency)

    assert_response :success
    assert_includes response.body, "What would you like to represent?"
    assert_includes response.body, "Choose the type of identity you&#39;d like to create."
    assert_includes response.body, "Continue"
    assert_includes response.body, "Company"
    refute_includes response.body, "Company name"

    get recording_studio_identity.new_recording_identity_path(@agency, kind: "company")

    assert_response :success
    assert_includes response.body, "Company name"
    assert_includes response.body, "About the company"
    assert_includes response.body, "Company logo"
    assert_includes response.body, "Upload image"
    assert_includes response.body, "image[signed_blob_id]"
    assert_includes response.body, "recording-studio-attachable--attachment-revision-upload"
    assert_includes response.body, "attachment-revision-upload#fileSelected"
    assert_identity_form_order(response.body, removable: false)
  end

  test "creating from the details form shows the identity and omits empty fields" do
    get recording_studio_identity.new_recording_identity_path(@agency, kind: "brand")
    assert_response :success

    assert_difference -> { RecordingStudioIdentity.identities(@agency).size }, 1 do
      post recording_studio_identity.recording_identities_path(@agency), params: {
        idempotency_key: css_select("input[name='idempotency_key']").first["value"],
        identity: { kind: "brand", name: "Harbour Mark", description: "", website_url: "" }
      }
    end
    assert_redirected_to %r{/identities/}

    follow_redirect!
    assert_includes response.body, "Harbour Mark"
    assert_includes response.body, "Brand"
    refute_includes response.body, "https://example.com"
  end

  test "edit uses category labels and does not offer a kind field" do
    identity = RecordingStudioIdentity.identities(@studio).sole

    get recording_studio_identity.edit_identity_path(identity)

    assert_response :success
    assert_includes response.body, "Full name"
    assert_includes response.body, "Biography"
    assert_includes response.body, "Change image"
    assert_includes response.body, "Remove image"
    assert_includes response.body, "recording-studio-attachable--attachment-revision-upload"
    refute_includes response.body, "identity[kind]"
    assert_identity_form_order(response.body, removable: true)

    patch recording_studio_identity.identity_path(identity), params: {
      identity: { name: "Sarah Jones", description: "Photographer and creator", website_url: "https://example.com" }
    }
    assert_redirected_to recording_studio_identity.identity_path(identity)
    assert_equal identity.recordable_id, identity.reload.recordable_id
  end

  test "trash and restore keep the one slot" do
    identity = RecordingStudioIdentity.identity(@studio)

    delete recording_studio_identity.identity_path(identity)
    assert_redirected_to recording_studio_identity.recording_identities_path(@studio)

    follow_redirect!
    assert_includes response.body, "Restore identity"
    refute_includes response.body, "+ Identity"

    get recording_studio_identity.edit_identity_path(identity)
    assert_redirected_to recording_studio_identity.identity_path(identity)

    post recording_studio_identity.restore_identity_path(identity)
    assert_redirected_to recording_studio_identity.identity_path(identity)
    assert_nil identity.reload.trashed_at
  end

  test "a nested parent lists its identity" do
    get recording_studio_identity.recording_identities_path(@project)

    assert_response :success
    assert_includes response.body, "Harbour Trust"
    assert_includes response.body, "+ Identity"
  end

  test "zero categories render a configuration error and one category skips the chooser" do
    with_categories({}) do
      get recording_studio_identity.new_recording_identity_path(@agency)
      assert_response :success
      assert_includes response.body, "No identity categories are configured"
    end

    with_categories(person: { label: "Person", fields: { name: "Full name" } }) do
      get recording_studio_identity.new_recording_identity_path(@agency)
      assert_response :success
      assert_includes response.body, "Full name"
      refute_includes response.body, "What would you like to represent?"
    end
  end

  test "unknown kind and a folder parent do not create a recording" do
    recordings = RecordingStudio::Recording.count

    get recording_studio_identity.new_recording_identity_path(@agency, kind: "mascot")
    assert_response :success
    assert_includes response.body, "Choose one of the configured categories."

    folder = RecordingStudio::Recording.find_by!(recordable: Folder.find_by!(name: "Product Docs"))
    get recording_studio_identity.recording_identities_path(folder)
    assert_response :not_found

    assert_equal recordings, RecordingStudio::Recording.count
  end

  test "display helpers render initials, the name, and an optional website" do
    identity = RecordingStudioIdentity.identity(@studio)
    html = ApplicationController.renderer.render(
      inline: <<~ERB,
        <%= recording_studio_identity_image(@identity, size: :lg, shape: :circle) %>
        <%= recording_studio_identity_card(@identity) %>
        <%= recording_studio_identity_display_name(@identity) %>
      ERB
      assigns: { identity: identity }
    )

    assert_includes html, "Sarah Jones"
    assert_includes html, "https://example.com"
    assert_includes html, "data-recording-studio-identity-card"
  end

  private

  test "create and edit failures stay on the form" do
    get recording_studio_identity.new_recording_identity_path(@studio)
    assert_redirected_to recording_studio_identity.recording_identities_path(@studio)

    post recording_studio_identity.recording_identities_path(@studio), params: {
      identity: { kind: "brand", name: "Second" }
    }
    assert_redirected_to recording_studio_identity.recording_identities_path(@studio)

    post recording_studio_identity.recording_identities_path(@agency), params: {
      identity: { kind: "brand", name: "" }
    }
    assert_response :unprocessable_content

    identity = RecordingStudioIdentity.identity(@studio)
    patch recording_studio_identity.identity_path(identity), params: {
      identity: { name: "Sarah Jones", website_url: "javascript:alert(1)" }
    }
    assert_response :unprocessable_content

    patch recording_studio_identity.image_identity_path(identity), params: { image: { signed_blob_id: "" } }
    assert_redirected_to recording_studio_identity.edit_identity_path(identity)

    delete recording_studio_identity.image_identity_path(identity)
    assert_redirected_to recording_studio_identity.edit_identity_path(identity)
  end

  test "a one slot parent with two identities explains the conflict" do
    extra = RecordingStudioIdentity::Identity.create!(name: "Extra", kind: "person", created_at: Time.current)
    occupant = RecordingStudioIdentity.identity(@studio)
    RecordingStudio::Recording.new(
      root_recording: @studio,
      parent_recording: @studio,
      recordable: extra
    ).save!(validate: false)

    get recording_studio_identity.recording_identities_path(@studio)

    assert_response :success
    assert_includes response.body, occupant.recordable.name
    assert_includes response.body, "Extra"
  end

  test "display helpers name a recording from its title or id" do
    helpers = Object.new.extend(RecordingStudioIdentity::IdentitiesHelper)
    page = RecordingStudio::Recording.find_by!(recordable: Page.find_by!(title: "Getting Started"))

    assert_equal "Getting Started", helpers.identity_recording_name(page)
    assert_equal "Name", helpers.identity_field_label(nil, :name)
    assert_equal page.id, helpers.identity_recording_name(RecordingStudio::Recording.new(id: page.id))
  end

  def assert_identity_form_order(body, removable:)
    document = Nokogiri::HTML(body)
    form = document.css("form").find { |node| node.at_css("[name='identity[name]']") }
    refute_nil form
    assert_includes form["data-controller"].to_s, "recording-studio-attachable--attachment-revision-upload"
    assert_nil form.at_css("[data-testid='identity-image-field'] form")

    fields = [
      form.at_css("[name='identity[name]']"),
      form.at_css("[name='identity[website_url]']"),
      form.at_css("[name='identity[description]']"),
      form.at_css("[data-testid='identity-image-field']"),
      form.css("button").find { |button| button.text.include?("Save") }
    ]
    assert fields.all?
    assert_equal fields, fields.sort
    refute_includes body, "You can add an image now or after the identity is saved."

    if removable
      refute_nil document.at_css("form#remove-identity-image")
      assert_nil form.at_css("#remove-identity-image")
      refute_nil form.at_css("[data-testid='identity-image-field'] button[form='remove-identity-image']")
    else
      assert_nil document.at_css("form#remove-identity-image")
      assert_nil document.at_css("button[form='remove-identity-image']")
    end
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
