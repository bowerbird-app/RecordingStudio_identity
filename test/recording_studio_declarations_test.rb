# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "test_helper"
require_relative "dummy/config/environment"

require "rails/test_help"

class RecordingStudioDeclarationsTest < ActiveSupport::TestCase
  test "dummy recordable declarations validate and expose parent/root introspection" do
    assert RecordingStudio.validate_recordable_declarations!
    assert_not_includes RecordingStudio.configuration.recordable_types.map(&:to_s), "RecordingStudioApi::AdminApi"
    assert_equal %w[Agency Workspace], RecordingStudio.root_recordable_types.sort
    assert_equal %w[Workspace Folder], RecordingStudio.allowed_parent_types_for("Folder")
    assert_equal %w[Workspace Folder], RecordingStudio.allowed_parent_types_for(Page)
  end

  test "root recordable creates a root recording" do
    workspace = Workspace.create!(name: unique_name("Root Workspace"))

    assert_nil RecordingStudio.root_recording_for(workspace)

    root_recording = create_root!(workspace)

    assert_predicate root_recording, :persisted?
    assert_equal workspace, root_recording.recordable
    assert_nil root_recording.parent_recording_id
    assert_equal root_recording.id, root_recording.root_recording_id
    assert_equal root_recording, RecordingStudio.root_recording_for(workspace)
  end

  test "allowed child can be recorded under a workspace root" do
    root_recording = create_root!(Workspace.create!(name: unique_name("Child Workspace")))
    folder = Folder.new(name: unique_name("Allowed Folder"))
    actor = writer_for(root_recording)

    event = RecordingStudio.record!(
      action: "created",
      recordable: folder,
      root_recording: root_recording,
      parent_recording: root_recording,
      actor: actor
    )

    assert_equal folder, event.recording.recordable
    assert_equal root_recording, event.recording.parent_recording
  end

  test "page can be recorded under allowed workspace and folder parents" do
    root_recording = create_root!(Workspace.create!(name: unique_name("Page Workspace")))
    folder_recording = record_child(Folder.new(name: unique_name("Page Folder")), root_recording, root_recording)

    workspace_page_recording = record_child(
      Page.new(title: unique_name("Workspace Page")),
      root_recording,
      root_recording
    )
    folder_page_recording = record_child(Page.new(title: unique_name("Folder Page")), root_recording, folder_recording)

    assert_equal root_recording, workspace_page_recording.parent_recording
    assert_equal folder_recording, folder_page_recording.parent_recording
  end

  test "child recordable cannot be created as a root" do
    folder = Folder.create!(name: unique_name("Root Rejected Folder"))

    assert_raises(RecordingStudio::RootNotAllowed) do
      RecordingStudio.root_recording_for(folder)
    end
  end

  test "parentless child under an existing root is invalid" do
    root_recording = create_root!(Workspace.create!(name: unique_name("Parentless Workspace")))
    folder = Folder.create!(name: unique_name("Parentless Folder"))
    recording = RecordingStudio::Recording.new(root_recording: root_recording, recordable: folder)

    assert_not recording.valid?
    assert_includes recording.errors[:parent_recording_id].join, "cannot be blank"
  end

  test "page cannot be recorded under another page" do
    root_recording = create_root!(Workspace.create!(name: unique_name("Invalid Page Workspace")))
    page_recording = record_child(Page.new(title: unique_name("Parent Page")), root_recording, root_recording)

    error = assert_raises(RecordingStudio::InvalidParent) do
      record_child(Page.new(title: unique_name("Nested Page")), root_recording, page_recording)
    end
    assert_equal "Page cannot be recorded under Page", error.message
  end

  test "accessible and identities stay opt-in on workspace" do
    assert RecordingStudio.capability_enabled?(:accessible, for: "Workspace")
    refute RecordingStudio.capability_enabled?(:accessible, for: "Folder")
    refute RecordingStudio.capability_enabled?(:accessible, for: "Page")

    assert RecordingStudio.capability_enabled?(:identities, for: "Workspace")
    assert RecordingStudio.capability_enabled?(:identities, for: "Agency")
    assert RecordingStudio.capability_enabled?(:identities, for: "Project")
    refute RecordingStudio.capability_enabled?(:identities, for: "Folder")
    refute RecordingStudio.capability_enabled?(:identities, for: "Page")
    assert_equal :one, RecordingStudio.capability_options(:identities, for: "Workspace").to_h[:allow]
  end

  test "image and a one-identity parent are pairwise single children" do
    assert RecordingStudio.single_child?(
      "RecordingStudioAttachable::Attachment",
      under: "RecordingStudioIdentity::Identity"
    )
    refute RecordingStudio.single_child?("RecordingStudioAttachable::Attachment", under: "Workspace")
    assert RecordingStudio.single_child?("RecordingStudioIdentity::Identity", under: "Workspace")
    refute RecordingStudio.single_child?("RecordingStudioIdentity::Identity", under: "Agency")
    refute RecordingStudio.single_child?("RecordingStudioIdentity::Identity", under: "Project")
    assert RecordingStudio.capability_enabled?(:trashable, for: "RecordingStudioAttachable::Attachment")

    index_types = RecordingStudio.single_child_index_types
    refute_includes index_types, "RecordingStudioIdentity::Identity"
    refute_includes index_types, "RecordingStudioAttachable::Attachment"
  end

  private

  def create_root!(recordable)
    actor = User.create!(
      email: "root-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    Current.actor = actor
    RecordingStudio.create_root_recording!(recordable, actor: actor)
  end

  def record_child(recordable, root_recording, parent_recording)
    RecordingStudio.record!(
      action: "created",
      recordable: recordable,
      root_recording: root_recording,
      parent_recording: parent_recording,
      actor: writer_for(root_recording)
    ).recording
  end

  def writer_for(root_recording)
    @writers ||= {}
    @writers[root_recording.id] ||= begin
      actor = User.create!(
        email: "writer-#{SecureRandom.hex(4)}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      )
      Current.actor = actor
      result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root_recording, actor: actor)
      raise result.error if result.failure?

      actor
    end
  end

  def unique_name(prefix)
    "#{prefix} #{SecureRandom.hex(4)}"
  end
end
