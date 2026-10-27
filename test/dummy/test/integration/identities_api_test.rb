# frozen_string_literal: true

require "test_helper"
require "base64"
require "stringio"

class IdentitiesApiTest < ActiveSupport::TestCase
  TINY_PNG = Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
  ).freeze

  setup do
    @actor = User.create!(
      email: "identity-api-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    Current.actor = @actor
    @workspace = owned_root(Workspace)
    @agency = owned_root(Agency)
  end

  teardown do
    Current.actor = nil
  end

  test "create returns the recording and normalizes fields" do
    identity = RecordingStudioIdentity.create(
      @workspace,
      actor: @actor,
      kind: " Person ",
      name: "  Ada Lovelace  ",
      description: "   ",
      website_url: "  https://ada.example/  "
    )

    assert_equal "RecordingStudioIdentity::Identity", identity.recordable_type
    assert_equal "Ada Lovelace", identity.recordable.name
    assert_equal "person", identity.recordable.kind
    assert_nil identity.recordable.description
    assert_equal "https://ada.example/", identity.recordable.website_href
    assert_equal identity, RecordingStudioIdentity.identity(@workspace)
    assert_equal [identity], RecordingStudioIdentity.identities(@workspace)
    assert_equal "Ada Lovelace", RecordingStudioIdentity.display_name(identity)
  end

  test "unknown kind and unsafe website are rejected on create and kept on revise" do
    assert_raises(RecordingStudioIdentity::Invalid) do
      RecordingStudioIdentity.create(@workspace, actor: @actor, kind: "mascot", name: "Nope")
    end
    assert_raises(RecordingStudioIdentity::Invalid) do
      RecordingStudioIdentity.create(@workspace, actor: @actor, kind: "person", name: "Nope", website_url: "javascript:alert(1)")
    end

    identity = RecordingStudioIdentity.create(@workspace, actor: @actor, kind: "person", name: "Kept")
    with_categories(company: { label: "Company" }) do
      revised = RecordingStudioIdentity.update(identity, actor: @actor, name: "Still kept")

      assert_equal identity.id, revised.id
      assert_equal "person", revised.recordable.kind
      assert_nil RecordingStudioIdentity.category_for(revised)
      assert_raises(RecordingStudioIdentity::Invalid) do
        RecordingStudioIdentity.create(@agency, actor: @actor, kind: "person", name: "New person")
      end
    end
  end

  test "update keeps the recording id and skips an unchanged revision" do
    identity = RecordingStudioIdentity.create(
      @workspace, actor: @actor, kind: "person", name: "Ada", description: "Maths"
    )
    events = RecordingStudio::Event.where(recording_id: identity.id).count

    same = RecordingStudioIdentity.update(identity, actor: @actor, name: "Ada", description: "Maths")
    assert_equal identity.recordable_id, same.recordable_id
    assert_equal events, RecordingStudio::Event.where(recording_id: identity.id).count

    renamed = RecordingStudioIdentity.update(identity, actor: @actor, name: "Ada King")
    assert_equal identity.id, renamed.id
    assert_not_equal identity.recordable_id, renamed.recordable_id
    assert_equal "Ada King", RecordingStudioIdentity.find(identity.id).recordable.name
    assert_raises(ArgumentError) do
      RecordingStudioIdentity.update(identity, actor: @actor, kind: "brand", name: "Ada King")
    end
  end

  test "idempotency key returns the original recording even after trash" do
    created = RecordingStudioIdentity.create(
      @workspace, actor: @actor, kind: "person", name: "Ada", idempotency_key: "ada-once"
    )
    created.recording_studio_trashable_trash!(actor: @actor)

    again = RecordingStudioIdentity.create(
      @workspace, actor: @actor, kind: "brand", name: "Other", idempotency_key: "ada-once"
    )

    assert_equal created.id, again.id
    assert_predicate again, :trashed_at
    assert_nil RecordingStudioIdentity.identity(@workspace)
    assert_equal created, RecordingStudioIdentity.identity(@workspace, include_trashed: true)
  end

  test "one slot stays occupied while the identity is trashed" do
    created = RecordingStudioIdentity.create(@workspace, actor: @actor, kind: "person", name: "Ada")
    created.recording_studio_trashable_trash!(actor: @actor)

    error = assert_raises(RecordingStudioIdentity::IdentityAlreadyExists) do
      RecordingStudioIdentity.create(@workspace, actor: @actor, kind: "brand", name: "Other")
    end
    assert_equal created.id, error.identity.id

    created.recording_studio_trashable_restore!(actor: @actor)
    assert_equal "Ada", RecordingStudioIdentity.identity(@workspace).recordable.name
    assert_raises(RecordingStudioIdentity::Trashed) do
      created.recording_studio_trashable_trash!(actor: @actor)
      RecordingStudioIdentity.update(created, actor: @actor, name: "Changed")
    end
  end

  test "many identities are listed by name and identity is refused" do
    zebra = RecordingStudioIdentity.create(@agency, actor: @actor, kind: "brand", name: "Zebra")
    alpha = RecordingStudioIdentity.create(@agency, actor: @actor, kind: "company", name: "Alpha")
    zebra.recording_studio_trashable_trash!(actor: @actor)

    assert_equal [alpha], RecordingStudioIdentity.identities(@agency)
    assert_equal [alpha, zebra], RecordingStudioIdentity.identities(@agency, include_trashed: true)
    assert_raises(RecordingStudioIdentity::ManyIdentitiesAllowed) do
      RecordingStudioIdentity.identity(@agency)
    end
  end

  test "find rejects other recordings and parents that cannot hold identities" do
    folder = Folder.create!(name: "Loose folder")
    folder_recording = RecordingStudio.record!(
      action: "created", recordable: folder, root_recording: @workspace,
      parent_recording: @workspace, actor: @actor
    ).recording

    assert_raises(RecordingStudioIdentity::NotFound) { RecordingStudioIdentity.find(folder_recording.id) }
    assert_raises(RecordingStudioIdentity::NotFound) { RecordingStudioIdentity.find(nil) }
    assert_raises(RecordingStudioIdentity::ParentNotAllowed) do
      RecordingStudioIdentity.identities(folder_recording)
    end
    assert_raises(RecordingStudioIdentity::ParentNotAllowed) do
      RecordingStudioIdentity.create(folder_recording, actor: @actor, kind: "person", name: "Ada")
    end
  end

  test "authorization is checked on the parent and does not leak across roots" do
    stranger = User.create!(
      email: "stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    identity = RecordingStudioIdentity.create(@workspace, actor: @actor, kind: "person", name: "Ada")

    assert RecordingStudioIdentity.can?(:view, @workspace, actor: @actor)
    assert RecordingStudioIdentity.can?(:trash, identity, actor: @actor)
    refute RecordingStudioIdentity.can?(:create, @workspace, actor: stranger)
    assert_raises(RecordingStudioIdentity::NotAuthorized) do
      RecordingStudioIdentity.create(@workspace, actor: stranger, kind: "brand", name: "Other")
    end
    assert_raises(ArgumentError) { RecordingStudioIdentity.can?(:duplicate, identity, actor: @actor) }
    assert_empty RecordingStudioIdentity.identities(@agency)
  end

  test "a nested project can hold its own identities" do
    project = Project.create!(name: "Nested #{SecureRandom.hex(3)}")
    parent = RecordingStudio.record!(
      action: "created", recordable: project, root_recording: @workspace,
      parent_recording: @workspace, actor: @actor
    ).recording
    identity = RecordingStudioIdentity.create(parent, actor: @actor, kind: "organisation", name: "Harbour Trust")

    assert_equal [identity], RecordingStudioIdentity.identities(parent)
    assert_empty RecordingStudioIdentity.identities(@workspace)
    assert_includes RecordingStudio.allowed_parent_types_for("RecordingStudioIdentity::Identity"), "Project"
  end

  test "image attach replace and remove use the attachment slot" do
    identity = RecordingStudioIdentity.create(@workspace, actor: @actor, kind: "person", name: "Ada")
    RecordingStudioIdentity.set_image(identity, signed_blob_id: issued_signed_id(identity), actor: @actor)
    image = RecordingStudioIdentity.image(identity)
    assert image
    assert_equal "image", image.recordable.name

    replaced = issued_blob(identity, "second.png")
    RecordingStudioIdentity.set_image(identity, signed_blob_id: issued_signed_id_for(replaced), actor: @actor)
    assert_equal 1, RecordingStudioIdentity::Slots.children(identity, RecordingStudioIdentity::IMAGE_TYPE).count

    text = issued_blob(identity, "notes.txt", content_type: "text/plain", body: "hello")
    assert_raises(RecordingStudioIdentity::ImageRejected) do
      RecordingStudioIdentity.set_image(identity, signed_blob_id: issued_signed_id_for(text), actor: @actor)
    end

    RecordingStudioIdentity.remove_image(identity, actor: @actor)
    assert_nil RecordingStudioIdentity.image(identity)
    assert_equal identity, RecordingStudioIdentity.remove_image(identity, actor: @actor)
  end

  test "trashing an identity trashes its image and restore brings it back" do
    identity = RecordingStudioIdentity.create(@workspace, actor: @actor, kind: "person", name: "Ada")
    RecordingStudioIdentity.set_image(identity, signed_blob_id: issued_signed_id(identity), actor: @actor)
    identity.recording_studio_trashable_trash!(actor: @actor)
    assert_nil RecordingStudioIdentity.image(identity)

    identity.recording_studio_trashable_restore!(actor: @actor)
    assert RecordingStudioIdentity.image(identity)
  end

  test "allow must be one or many" do
    error = assert_raises(RecordingStudioIdentity::ConfigurationError) do
      RecordingStudio::Capabilities::Identities.to(allow: :two)
    end
    assert_includes error.message, "allow: :one or allow: :many"

    assert_raises(RecordingStudioIdentity::ConfigurationError) do
      RecordingStudio::Capabilities::Identities.to(allow: :one, label: "nope")
    end
  end

  test "field limits and http websites are enforced by the recordable" do
    record = RecordingStudioIdentity::Identity.new(name: "A" * 201, kind: "person", website_url: "example.com")
    assert_not record.valid?
    assert_includes record.errors[:name].join, "too long"
    assert_includes record.errors[:website_url].join, "HTTP"

    blank = RecordingStudioIdentity::Identity.new(name: "Ada", kind: "person", website_url: "http://example.com")
    assert_predicate blank, :valid?
    assert_equal "http://example.com", blank.website_href
  end

  private

  def owned_root(klass)
    recordable = klass.create!(name: "#{klass.name} #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(recordable)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: @actor)
    raise result.error if result.failure?

    root
  end

  def with_categories(definitions)
    configuration = RecordingStudioIdentity.configuration
    previous = configuration.categories
    configuration.types = definitions
    yield
  ensure
    configuration.instance_variable_set(:@categories, previous)
  end

  def png_blob(filename = "portrait.png")
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(TINY_PNG), filename: filename, content_type: "image/png"
    )
  end

  def issued_blob(recording, filename = "portrait.png", content_type: "image/png", body: TINY_PNG)
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(body),
      filename: filename,
      content_type: content_type,
      metadata: RecordingStudioAttachable::DirectUpload.metadata_for(recording: recording, actor: @actor)
    )
  end

  def issued_signed_id(recording, filename = "portrait.png")
    issued_signed_id_for(issued_blob(recording, filename))
  end

  def issued_signed_id_for(blob)
    blob.signed_id(purpose: RecordingStudioAttachable::DirectUpload::PURPOSE)
  end
end

class IdentitiesConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @actor = User.create!(
      email: "identity-race-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    @workspace = Workspace.create!(name: "Race #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @actor)
    raise result.error if result.failure?
  end

  teardown do
    recording_ids = RecordingStudio::Recording.unscoped.where(root_recording_id: @root.id).or(
      RecordingStudio::Recording.unscoped.where(id: @root.id)
    ).pluck(:id)
    RecordingStudio::Event.where(recording_id: recording_ids).delete_all
    RecordingStudio::Recording.unscoped.where(id: recording_ids).delete_all
    @workspace.delete
    @actor.delete
  end

  test "two creates cannot both take the single slot" do
    ready = Queue.new
    outcomes = Queue.new
    threads = 2.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          sleep 0.01 until ready.size >= 2
          outcomes << RecordingStudioIdentity.create(
            @root, actor: @actor, kind: "person", name: "Racer #{index}"
          ).id
        end
      rescue StandardError => e
        outcomes << e
      end
    end
    threads.each(&:join)
    results = 2.times.map { outcomes.pop }

    assert_equal 1, results.count { |result| result.is_a?(String) }
    assert_equal 1, results.count { |result| result.is_a?(RecordingStudioIdentity::IdentityAlreadyExists) }
    assert_equal 1, RecordingStudioIdentity.identities(@root, include_trashed: true).size
  end
end

class IdentitiesMigrationTest < ActiveSupport::TestCase
  test "identities migration creates the kind index and drops the table" do
    require Rails.root.join("db/migrate/20261026120000_create_recording_studio_identities.rb").to_s

    connection = ActiveRecord::Base.connection
    ActiveRecord::Migration.suppress_messages do
      CreateRecordingStudioIdentities.migrate(:down)
      assert_not connection.table_exists?(:recording_studio_identities)
      CreateRecordingStudioIdentities.migrate(:up)
    end
    RecordingStudioIdentity::Identity.reset_column_information
    assert connection.table_exists?(:recording_studio_identities)
    assert connection.column_exists?(:recording_studio_identities, :kind)
    assert connection.index_exists?(
      :recording_studio_identities,
      :kind,
      name: "index_recording_studio_identities_on_kind"
    )
  end
end
