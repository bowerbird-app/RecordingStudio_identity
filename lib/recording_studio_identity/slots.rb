# frozen_string_literal: true

module RecordingStudioIdentity
  module Slots
    ALLOWANCES = %i[one many].freeze
    MESSAGES = {
      identity: "Only one identity is allowed here",
      image: "An identity can have only one image"
    }.freeze

    module_function

    def parse!(value, type: nil)
      allowance = value.to_s.strip.downcase.to_sym if value.is_a?(Symbol) || value.is_a?(String)
      return allowance if ALLOWANCES.include?(allowance)

      where = " on #{type}" if type
      raise ConfigurationError, "Identities#{where} need allow: :one or allow: :many (got #{value.inspect})"
    end

    def verify!
      RecordingStudio.recordable_declarations
      unless RecordingStudio.configuration.recordable_types.include?(IDENTITY_TYPE)
        raise ConfigurationError, %(Add "#{IDENTITY_TYPE}" to config.recordable_types)
      end

      RecordingStudio.configuration.enabled_recordable_types_for(:identities).each do |type|
        if RecordingStudio.shared_root_type?(type)
          raise ConfigurationError, "#{type} is a shared root and cannot hold identities"
        end

        parse!(RecordingStudio.capability_options(:identities, for: type).to_h[:allow], type: type)
      end
    end

    def children(parent, type)
      RecordingStudio::Recording.unscoped.where(parent_recording_id: parent.id, recordable_type: type)
    end

    def occupant(parent, type, except: nil)
      scope = children(parent, type)
      scope = scope.where.not(id: except) if except
      scope.reorder(:created_at, :id).first
    end

    def sole_identity!(parent)
      occupants = children(parent, IDENTITY_TYPE).reorder(:created_at, :id).to_a
      raise IdentityIntegrityError.new(identities: occupants) if occupants.size > 1

      occupants.first
    end

    def vacant?(parent)
      RecordingStudioIdentity.allowance(parent) == :many || occupant(parent, IDENTITY_TYPE).nil?
    end

    def lock_parent!(parent)
      root_id = parent.root_recording_id
      RecordingStudio::Recording.unscoped.lock.find(root_id) if root_id.present? && root_id != parent.id
      RecordingStudio::Recording.unscoped.lock.find(parent.id)
    end

    def slot_for(child_type, parent)
      case child_type
      when IDENTITY_TYPE then :identity if RecordingStudioIdentity.allowance(parent) == :one
      when IMAGE_TYPE then :image if parent.recordable_type == IDENTITY_TYPE
      end
    end

    module Validation
      extend ActiveSupport::Concern

      included do
        validate :recording_studio_identity_slot_free, if: :recording_studio_identity_slot_candidate?
      end

      private

      def recording_studio_identity_slot_candidate?
        parent_recording_id.present? && [IDENTITY_TYPE, IMAGE_TYPE].include?(recordable_type) &&
          (new_record? || will_save_change_to_parent_recording_id?)
      end

      def recording_studio_identity_slot_free
        parent = RecordingStudio::Recording.unscoped.find_by(id: parent_recording_id)
        slot = parent && Slots.slot_for(recordable_type, parent)
        return unless slot

        Slots.lock_parent!(parent)
        return unless Slots.occupant(parent, recordable_type, except: id)

        errors.add(:base, :"#{slot}_taken", message: MESSAGES.fetch(slot))
      end
    end
  end
end
