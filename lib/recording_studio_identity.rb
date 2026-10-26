# frozen_string_literal: true

require "recording_studio"
require "recording_studio_accessible"
require "recording_studio_attachable"
require "recording_studio_trashable"
require "flat_pack"
require "recording_studio_identity/version"
require "recording_studio_identity/categories"
require "recording_studio_identity/terminology"
require "recording_studio_identity/configuration"
require "recording_studio_identity/engine"

# Public identities mounted under recordings that opt in.
#
# An identity is a RecordingStudio::Recording. Store the recording id.
# Reads do not authorize. Writes require Accessible :edit, and record! still
# runs the host's config.authorize_write.
module RecordingStudioIdentity
  IDENTITY_TYPE = "RecordingStudioIdentity::Identity"
  IMAGE_TYPE = "RecordingStudioAttachable::Attachment"
  IMAGE_NAME = "image"
  ACTIONS = %i[view create update trash restore].freeze
  private_constant :ACTIONS

  class Error < StandardError; end
  class ParentNotAllowed < Error; end
  class NotAuthorized < Error; end
  class NotFound < Error; end
  class ImageRejected < Error; end

  class IdentityAlreadyExists < Error
    attr_reader :identity

    def initialize(identity:)
      @identity = identity
      super("#{identity.recordable.name} is already the identity here")
    end
  end

  class IdentityIntegrityError < Error
    attr_reader :identities

    def initialize(identities:)
      @identities = identities
      super("Only one identity is allowed here, but #{identities.size} identities are recorded")
    end
  end

  class Invalid < Error
    attr_reader :record

    def initialize(record:)
      @record = record
      super(record.errors.full_messages.to_sentence)
    end
  end

  class Trashed < Error
    attr_reader :identity

    def initialize(identity:)
      @identity = identity
      super("Restore #{identity.recordable.name} before changing it")
    end
  end

  class ManyIdentitiesAllowed < ArgumentError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def categories
      configuration.categories
    end

    def category(key)
      configuration.category(key)
    end

    def category_for(identity)
      category(identity!(identity).recordable.kind)
    end

    def creation
      configuration.creation
    end

    def allowance(parent)
      type = parent!(parent).recordable_type
      return unless RecordingStudio.capability_enabled?(:identities, for: type)

      Slots.parse!(RecordingStudio.capability_options(:identities, for: type).to_h[:allow], type: type)
    end

    def identities(parent, include_trashed: false)
      parent_not_allowed!(parent) unless allowance(parent)

      scope = Slots.children(parent, IDENTITY_TYPE)
      scope = scope.where(trashed_at: nil) unless include_trashed
      by_name(scope).preload(:recordable).to_a
    end

    def identity(parent, include_trashed: false)
      case allowance(parent)
      when nil then parent_not_allowed!(parent)
      when :many
        raise ManyIdentitiesAllowed, "#{label_for(parent)} allows many identities; use identities(parent)"
      end

      occupant = Slots.sole_identity!(parent)
      occupant if occupant && (include_trashed || occupant.trashed_at.nil?)
    end

    def find(id, include_trashed: false)
      recording = RecordingStudio::Recording.unscoped.find_by(id: id, recordable_type: IDENTITY_TYPE) if id.present?
      raise NotFound, "No identity #{id.inspect}" if recording.nil? || (recording.trashed_at && !include_trashed)

      recording
    end

    def create(parent, actor:, idempotency_key: nil, signed_blob_id: nil, **fields)
      parent_not_allowed!(parent) unless allowance(parent)
      attributes = create_fields!(fields)
      authorize!(parent, :edit, actor)
      host_write do
        create_identity!(
          parent, attributes, actor: actor, key: idempotency_key.presence, signed_blob_id: signed_blob_id
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      create_failed!(parent, e)
    end

    def update(identity, actor:, **fields)
      identity!(identity)
      attributes = update_fields!(fields)
      authorize!(identity, :edit, actor)
      host_write { update_identity!(identity, attributes, actor: actor) }
    rescue ActiveRecord::RecordInvalid => e
      raise Invalid.new(record: e.record) if e.record.is_a?(Identity)

      raise
    end

    def set_image(identity, signed_blob_id:, actor:)
      current = live_identity_for_write!(identity, actor)
      host_write do
        RecordingStudio::Recording.transaction do
          existing = Slots.occupant(current, IMAGE_TYPE)
          existing ? replace_image!(existing, signed_blob_id, actor) : upload_image!(current, signed_blob_id, actor)
        end
      end
      current
    rescue RecordingStudioAttachable::StorageLimitError, ArgumentError => e
      raise ImageRejected, e.message
    end

    def remove_image(identity, actor:)
      current = live_identity_for_write!(identity, actor)
      image = Slots.occupant(current, IMAGE_TYPE)
      return current if image.nil? || image.trashed_at

      host_write do
        RecordingStudio::Recording.transaction do
          result = RecordingStudioAttachable::Services::RemoveAttachment.call(attachment_recording: image, actor: actor)
          raise ImageRejected, result.error if result.failure?
        end
      end
      current
    end

    def image(identity)
      image = Slots.occupant(identity!(identity), IMAGE_TYPE)
      image if image && image.trashed_at.nil?
    end

    def display_name(identity)
      identity!(identity).recordable.name
    end

    def can?(action, recording, actor:)
      unless ACTIONS.include?(action)
        raise ArgumentError, "Unknown action #{action.inspect}; expected one of #{ACTIONS.join(', ')}"
      end

      send(:"can_#{action}?", recording, actor)
    end

    def enforcing_category?
      Thread.current[:recording_studio_identity_enforce_kind] == true
    end

    private

    def enforcing_category
      previous = Thread.current[:recording_studio_identity_enforce_kind]
      Thread.current[:recording_studio_identity_enforce_kind] = true
      yield
    ensure
      Thread.current[:recording_studio_identity_enforce_kind] = previous
    end

    def can_view?(recording, actor) = allowed?(recording, :view, actor)

    def can_create?(parent, actor)
      allowance(parent).present? && Slots.vacant?(parent) && allowed?(parent, :edit, actor)
    end

    def can_update?(identity, actor) = live_identity?(identity) && allowed?(identity, :edit, actor)

    def can_trash?(identity, actor)
      live_identity?(identity) &&
        RecordingStudioTrashable.authorized?(action: :trash, actor: actor, recording: identity)
    end

    def can_restore?(identity, actor)
      identity_recording?(identity) && identity.trashed_at.present? &&
        RecordingStudioTrashable.authorized?(action: :restore, actor: actor, recording: identity)
    end

    def allowed?(recording, role, actor)
      return false if actor.nil?

      RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: role)
    end

    def authorize!(recording, role, actor)
      return if allowed?(recording, role, actor)

      raise NotAuthorized, "Changing this #{label_for(recording).downcase} needs #{role} access"
    end

    def parent!(parent)
      return parent if parent.is_a?(RecordingStudio::Recording) && parent.persisted?

      raise ArgumentError, "Expected a persisted RecordingStudio::Recording, got #{parent.class}"
    end

    def identity!(identity)
      return identity if identity_recording?(identity) && identity.persisted?

      raise ArgumentError, "Expected an identity recording; load one with RecordingStudioIdentity.find(id)"
    end

    def identity_recording?(recording)
      recording.is_a?(RecordingStudio::Recording) && recording.recordable_type == IDENTITY_TYPE
    end

    def live_identity?(recording) = identity_recording?(recording) && recording.trashed_at.nil?

    def live_identity_for_write!(identity, actor)
      identity!(identity)
      authorize!(identity, :edit, actor)
      current = RecordingStudio::Recording.unscoped.find(identity.id)
      raise Trashed.new(identity: current) if current.trashed_at

      current
    end

    def create_fields!(fields)
      assignable_fields!(fields, Identity::CREATE_FIELDS, "identity")
    end

    def update_fields!(fields)
      assignable_fields!(fields, Identity::UPDATE_FIELDS, "identity update")
    end

    def assignable_fields!(fields, allowed, label)
      unknown = fields.keys.map(&:to_sym) - allowed
      raise ArgumentError, "Unknown #{label} field(s): #{unknown.join(', ')}" if unknown.any?

      fields.transform_keys(&:to_sym)
    end

    def label_for(recording)
      RecordingStudio.recordable_type_label(recording.recordable_type)
    end

    def parent_not_allowed!(parent)
      raise ParentNotAllowed, "#{label_for(parent)} does not hold identities"
    end

    def by_name(scope)
      identities = Identity.arel_table
      recordings = RecordingStudio::Recording.arel_table
      join = recordings.join(identities).on(identities[:id].eq(recordings[:recordable_id])).join_sources
      scope.joins(join).reorder(identities[:name].lower, recordings[:created_at], recordings[:id])
    end

    def created_with_key(parent, key)
      return if key.nil?

      recording_id = RecordingStudio::Event.where(
        recording_id: Slots.children(parent, IDENTITY_TYPE).select(:id),
        action: "created",
        idempotency_key: key
      ).pick(:recording_id)
      RecordingStudio::Recording.unscoped.find(recording_id) if recording_id
    end

    def host_write
      yield
    rescue RecordingStudio::AuthorizationError => e
      raise NotAuthorized, e.message
    end

    def create_identity!(parent, attributes, actor:, key:, signed_blob_id:)
      RecordingStudio::Recording.transaction do
        Slots.lock_parent!(parent)
        created_with_key(parent, key) ||
          record_identity!(parent, attributes, actor: actor, key: key, signed_blob_id: signed_blob_id)
      end
    end

    def record_identity!(parent, attributes, actor:, key:, signed_blob_id:)
      recording = enforcing_category do
        RecordingStudio.record!(
          action: "created",
          recordable: Identity.new(attributes),
          root_recording: parent.root_recording_or_self,
          parent_recording: parent,
          actor: actor,
          idempotency_key: key
        ).recording
      end
      upload_image!(recording, signed_blob_id, actor) if signed_blob_id.present?
      recording
    end

    def create_failed!(parent, error)
      record = error.record
      raise Invalid.new(record: record) if record.is_a?(Identity)

      occupant = record.errors.of_kind?(:base, :identity_taken) && Slots.sole_identity!(parent)
      raise IdentityAlreadyExists.new(identity: occupant) if occupant

      raise error
    end

    def update_identity!(identity, attributes, actor:)
      RecordingStudio::Recording.transaction do
        locked = RecordingStudio::Recording.unscoped.lock.find(identity.id)
        raise Trashed.new(identity: locked) if locked.trashed_at

        revise_identity!(locked, attributes, actor: actor)
      end
    end

    def revise_identity!(locked, attributes, actor:)
      current = locked.recordable
      candidate = RecordingStudio.duplicate_recordable(current)
      candidate.assign_attributes(attributes)
      raise Invalid.new(record: candidate) unless candidate.valid?

      unchanged = Identity::UPDATE_FIELDS.all? do |field|
        candidate.public_send(field) == current.public_send(field)
      end
      return locked if unchanged

      locked.root_recording_or_self.revise(locked, actor: actor) do |recordable|
        recordable.assign_attributes(attributes)
      end
    end

    def upload_image!(identity, signed_blob_id, actor)
      result = RecordingStudioAttachable::Services::RecordAttachmentUpload.call(
        parent_recording: identity, signed_blob_id: signed_blob_id, actor: actor, name: IMAGE_NAME
      )
      raise ImageRejected, result.error if result.failure?
    rescue ArgumentError => e
      raise ImageRejected, e.message
    end

    def replace_image!(image, signed_blob_id, actor)
      result = RecordingStudioAttachable::Services::ReplaceAttachmentFile.call(
        attachment_recording: image, signed_blob_id: signed_blob_id, actor: actor, name: IMAGE_NAME
      )
      raise ImageRejected, result.error if result.failure?
      return unless image.trashed_at

      restored = RecordingStudioAttachable::Services::RestoreAttachment.call(
        attachment_recording: image.reload, actor: actor
      )
      raise ImageRejected, restored.error if restored.failure?
    end
  end
end

require "recording_studio_identity/slots"
require "recording_studio_identity/capability"
require "recording_studio_identity/copy"
require "recording_studio_identity/display_helper"
