# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.where(RecordingStudio::Recording.recording_studio_trashable_kept_sql).find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

# Create the admin user
user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

# Create the workspace recordables
workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
accessible_workspace = Workspace.find_or_create_by!(name: "Client Workspace")
private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Getting Started")
agency = Agency.find_or_create_by!(name: "Harbour Agency")
project = Project.find_or_create_by!(name: "Harbour fit-out")

previous_actor = Current.actor
Current.actor = user

begin
  # Create the root recording
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)

  find_or_record_child.call(page, root_recording, folder_recording)
  agency_recording = RecordingStudio.root_recording_for(agency)
  project_recording = find_or_record_child.call(project, root_recording, root_recording)

  [root_recording, accessible_root_recording, agency_recording].each do |recording|
    next if RecordingStudioAccessible.authorized?(actor: user, recording: recording, role: :edit)

    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: user)
    raise result.error if result.failure?
  end

  ensure_identity = lambda do |parent, kind:, name:, **fields|
    existing = RecordingStudioIdentity.identities(parent, include_trashed: true).find do |identity|
      identity.recordable.name == name
    end
    next existing if existing

    RecordingStudioIdentity.create(parent, actor: user, kind: kind, name: name, **fields)
  end

  ensure_identity.call(
    root_recording,
    kind: "person",
    name: "Sarah Jones",
    description: "Photographer and creator",
    website_url: "https://example.com"
  )
  ensure_identity.call(agency_recording, kind: "company", name: "Northwind", description: "An independent agency")
  ensure_identity.call(agency_recording, kind: "brand", name: "Dove")
  ensure_identity.call(project_recording, kind: "organisation", name: "Harbour Trust")
ensure
  Current.actor = previous_actor
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
puts "Seeded: Agency '#{agency.name}' and project '#{project.name}'"
