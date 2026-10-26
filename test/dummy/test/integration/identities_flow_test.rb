# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "stringio"
require "base64"

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
    assert_includes response.body, "One press profile"
    assert_includes response.body, "Many press profiles"
    assert_includes response.body, "Nested parent"
    assert_includes response.body, "Creation text"
  end

  test "many index lists identities and one index shows the occupant" do
    get recording_studio_identity.recording_identities_path(@agency)

    assert_response :success
    assert_includes response.body, "Northwind"
    assert_includes response.body, "Dove"
    assert_includes response.body, "Press profiles"
    assert_includes response.body, "+ Press profile"
    refute_includes response.body, "+ Identity"

    get recording_studio_identity.recording_identities_path(@studio)

    assert_response :success
    assert_includes response.body, "Sarah Jones"
    assert_includes response.body, "Press profiles"
    refute_includes response.body, "+ Press profile"
  end

  test "category selection uses configured copy and shared field labels" do
    get recording_studio_identity.new_recording_identity_path(@agency)

    assert_response :success
    assert_includes response.body, "Who is this press profile for?"
    assert_includes response.body, "Choose the type of press profile you&#39;d like to create."
    assert_includes response.body, "Continue"
    assert_includes response.body, "Company"
    refute_includes response.body, "Company name"

    get recording_studio_identity.new_recording_identity_path(@agency, kind: "company")

    assert_response :success
    assert_includes response.body, "Add press profile"
    assert_includes response.body, "Name"
    assert_includes response.body, "Website"
    assert_includes response.body, "About"
    assert_includes response.body, "Image"
    refute_includes response.body, "Company name"
    refute_includes response.body, "About the company"
    refute_includes response.body, "Company logo"
    assert_includes response.body, "image[signed_blob_id]"
    assert_includes response.body, "image[file]"
    assert_includes response.body, "flat-pack--image-input"
    assert_includes response.body, "recording-studio-attachable--attachment-revision-upload"
    assert_includes response.body, "attachment-revision-upload#fileSelected"
    refute_includes response.body, "Upload image"
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
    assert_includes response.body, "Edit press profile"
    assert_includes response.body, "Name"
    assert_includes response.body, "About"
    refute_includes response.body, "Full name"
    refute_includes response.body, "Biography"
    assert_includes response.body, "Remove image"
    assert_includes response.body, "flat-pack--image-input"
    assert_includes response.body, "recording-studio-attachable--attachment-revision-upload"
    refute_includes response.body, "Change image"
    refute_includes response.body, "identity[kind]"
    assert_identity_form_order(response.body, removable: true)

    patch recording_studio_identity.identity_path(identity), params: {
      identity: { name: "Sarah Jones", description: "Photographer and creator", website_url: "https://example.com" }
    }
    assert_redirected_to recording_studio_identity.identity_path(identity)
    assert_equal identity.recordable_id, identity.reload.recordable_id
  end

  test "saving a cleared image removes it and an empty file does not replace it" do
    identity = RecordingStudioIdentity.identity(@studio)
    image = RecordingStudioIdentity.image(identity)
    original_blob_id = image.recordable.file.blob.id
    stale = png_blob

    patch recording_studio_identity.identity_path(identity), params: {
      identity: { name: "Sarah Jones", description: "Photographer", website_url: "https://example.com" },
      image: { signed_blob_id: stale.signed_id, file: "", remove: "0" }
    }
    assert_redirected_to recording_studio_identity.identity_path(identity)
    assert_equal original_blob_id, RecordingStudioIdentity.image(identity.reload).recordable.file.blob.id

    patch recording_studio_identity.identity_path(identity), params: {
      identity: { name: "Sarah Jones", description: "Photographer", website_url: "https://example.com" },
      image: { signed_blob_id: stale.signed_id, remove: "1", file: fixture_file("portrait.png") }
    }
    assert_redirected_to recording_studio_identity.identity_path(identity)
    assert_equal stale.id, RecordingStudioIdentity.image(identity.reload).recordable.file.blob.id

    patch recording_studio_identity.identity_path(identity), params: {
      identity: { name: "Sarah Jones", description: "Photographer", website_url: "https://example.com" },
      image: { signed_blob_id: "", remove: "1" }
    }
    assert_redirected_to recording_studio_identity.identity_path(identity)
    assert_nil RecordingStudioIdentity.image(identity.reload)
  end

  test "creating with an empty file ignores a leftover signed blob" do
    blob = png_blob
    assert_difference -> { RecordingStudioIdentity.identities(@agency).size }, 1 do
      post recording_studio_identity.recording_identities_path(@agency), params: {
        idempotency_key: SecureRandom.uuid,
        identity: { kind: "brand", name: "Empty Frame", description: "", website_url: "" },
        image: { signed_blob_id: blob.signed_id, file: "" }
      }
    end
    assert_redirected_to %r{/identities/}

    created = RecordingStudioIdentity.identities(@agency).find { |recording| recording.recordable.name == "Empty Frame" }
    assert_nil RecordingStudioIdentity.image(created)
  end

  test "trash and restore keep the one slot" do
    identity = RecordingStudioIdentity.identity(@studio)

    delete recording_studio_identity.identity_path(identity)
    assert_redirected_to recording_studio_identity.recording_identities_path(@studio)

    follow_redirect!
    assert_includes response.body, "Restore press profile"
    refute_includes response.body, "+ Press profile"

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
    assert_includes response.body, "+ Press profile"
  end

  test "zero categories render a configuration error and one category skips the chooser" do
    with_categories({}) do
      get recording_studio_identity.new_recording_identity_path(@agency)
      assert_response :success
      assert_includes response.body, "No press profile categories are configured"
    end

    with_categories(person: { label: "Person", fields: { name: "Full name" } }) do
      get recording_studio_identity.new_recording_identity_path(@agency)
      assert_response :success
      assert_includes response.body, "Full name"
      refute_includes response.body, "Who is this press profile for?"
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
    field = form.at_css("[data-testid='identity-image-field']")
    refute_nil field
    assert_nil field.at_css("form")
    refute_nil field.at_css("[data-controller*='flat-pack--image-input']")
    file_input = field.at_css("input[type='file'][name='image[file]']")
    refute_nil file_input
    assert_includes file_input["data-action"].to_s, "flat-pack--image-input#choose"
    assert_includes file_input["data-action"].to_s, "attachment-revision-upload#fileSelected"
    refute_nil field.at_css("[data-recording-studio-attachable--attachment-revision-upload-target='signedBlobInput']")

    layout = form.at_css("[data-identity-form-layout='columns']")
    refute_nil layout
    assert_includes layout["class"], "grid-cols-1"
    assert_includes layout["class"], "md:grid-cols-[auto_1fr]"
    columns = layout.element_children
    assert_equal "image", columns[0]["data-identity-form-column"]
    assert_equal "details", columns[1]["data-identity-form-column"]
    assert columns[0].at_css("[data-testid='identity-image-field']")
    assert columns[1].at_css("[name='identity[name]']")
    assert columns[1].at_css("[name='identity[website_url]']")
    assert columns[1].at_css("[name='identity[description]']")
    assert_nil columns[1].at_css("[data-testid='identity-image-field']")

    fields = [
      field,
      form.at_css("[name='identity[name]']"),
      form.at_css("[name='identity[website_url]']"),
      form.at_css("[name='identity[description]']"),
      form.css("button").find { |button| button.text.include?("Save") }
    ]
    assert fields.all?
    assert_equal fields, fields.sort
    assert_nil layout.css("button").find { |button| button.text.include?("Save") }
    refute_includes body, "You can add an image now or after the identity is saved."
    assert_nil document.at_css("form#remove-identity-image")

    clear = field.at_css("button[aria-label='Remove image']")
    refute_nil clear
    if removable
      remove = field.at_css("input[type='hidden'][name='image[remove]']")
      refute_nil remove
      assert_equal "0", remove["value"]
      assert_nil clear["hidden"]
    else
      assert_nil field.at_css("input[name='image[remove]']")
      assert clear["hidden"]
    end
  end

  def png_blob(filename = "portrait.png")
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(tiny_png), filename: filename, content_type: "image/png"
    )
  end

  def fixture_file(filename)
    path = Rails.root.join("tmp/#{filename}")
    File.binwrite(path, tiny_png)
    Rack::Test::UploadedFile.new(path.to_s, "image/png")
  end

  def tiny_png
    @tiny_png ||= Base64.decode64(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )
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
