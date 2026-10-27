# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "stringio"

class PageNavTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load_seeds
    @user = User.find_by!(email: "admin@admin.com")
    sign_in @user
    @agency = RecordingStudio::Recording.find_by!(recordable: Agency.find_by!(name: "Harbour Agency"))
    @studio = RecordingStudio::Recording.find_by!(recordable: Workspace.find_by!(name: "Studio Workspace"))
  end

  test "index puts add in the layout right slot and back in the page nav" do
    get recording_studio_identity.recording_identities_path(@agency)

    assert_response :success
    assert_select "h1", count: 1, text: "Press profiles"
    assert_select "nav.flat-pack-page-nav a[data-fp-style=default]", text: "+ Press profile", count: 0
    assert_select "header.fp-top-nav .fp-top-nav__right a[data-fp-style=default]", text: "+ Press profile"
    assert_select "nav.flat-pack-page-nav a[href='/']"
  end

  test "choose has one heading and no subtitle" do
    get recording_studio_identity.new_recording_identity_path(@agency)

    assert_response :success
    assert_select "h1", count: 1, text: "Who is this press profile for?"
    assert_select "h1 + *", text: /Choose the type of press profile/, count: 0
  end

  test "register_page_nav renders a link the layout button group can show" do
    html = ApplicationController.renderer.render(inline: <<~ERB)
      <% register_page_nav "Edit press profile", "/identities/1/edit", role: :secondary %>
      <%= page_nav_button_group(styles: { secondary: { style: :ghost, size: :sm } }) %>
    ERB

    assert_includes html, "Edit press profile"
    assert_includes html, "/identities/1/edit"
  end

  test "show uses the page nav back link and one heading" do
    identity = RecordingStudioIdentity.identity(@studio)

    get recording_studio_identity.identity_path(identity)

    assert_response :success
    assert_select "h1", count: 1, text: "Sarah Jones"
    assert_select "nav.flat-pack-page-nav a"
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
