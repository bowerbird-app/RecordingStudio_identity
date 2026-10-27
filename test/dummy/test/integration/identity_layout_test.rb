# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "stringio"

class IdentityLayoutTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load_seeds
    @user = User.find_by!(email: "admin@admin.com")
    sign_in @user
    @agency = RecordingStudio::Recording.find_by!(recordable: Agency.find_by!(name: "Harbour Agency"))
    @layout = RecordingStudioIdentity.configuration.layout
  end

  teardown do
    RecordingStudioIdentity.configuration.layout = @layout
  end

  test "nil layout renders the recording studio default layout and one heading" do
    RecordingStudioIdentity.configuration.layout = nil

    get recording_studio_identity.recording_identities_path(@agency)

    assert_response :success
    assert_select "[data-recording-studio-default-layout=true]"
    assert_select "h1", count: 1, text: "Press profiles"
  end

  test "a layout name replaces the default layout" do
    RecordingStudioIdentity.configuration.layout = "application"

    get recording_studio_identity.recording_identities_path(@agency)

    assert_response :success
    assert_select "[data-recording-studio-default-layout]", count: 0
    assert_select "main"
    assert_includes response.body, "Northwind"
  end

  test "false skips the layout" do
    RecordingStudioIdentity.configuration.layout = false

    get recording_studio_identity.recording_identities_path(@agency)

    assert_response :success
    assert_select "[data-recording-studio-default-layout]", count: 0
    assert_select "h1", count: 0
    assert_includes response.body, "Northwind"
  end

  test "a keyword callable chooses the layout for the controller" do
    RecordingStudioIdentity.configuration.layout = ->(controller:) do
      controller.is_a?(ActionController::Base) ? "application" : "recording_studio/default_layout"
    end

    get recording_studio_identity.recording_identities_path(@agency)

    assert_response :success
    assert_select "[data-recording-studio-default-layout]", count: 0
    assert_select "main"
  end

  private

  def load_seeds
    previous = $stdout
    $stdout = StringIO.new
    load Rails.root.join("db/seeds.rb").to_s
  ensure
    $stdout = previous
  end
end
