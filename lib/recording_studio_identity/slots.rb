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

    def parse_trashable!(value)
      return value if [true, false].include?(value)

      raise ConfigurationError, "Identities trashable: must be true or false (got #{value.inspect})"
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

    # :one is a single child under that parent type. :many clears the rule so a
    # reload that flips the allowance does not leave the slot in place.
    # Named parent rules stay out of the single-child index.
    def sync_parent_limit!(parent, allowance)
      type_name = parent.name.to_s
      return if type_name.blank?

      key = "recording_studio_identity.identity.#{type_name}"
      if allowance == :one
        RecordingStudio.declare_single_child(IDENTITY_TYPE, under: type_name, key: key)
      else
        RecordingStudio.remove_single_child(key)
      end
    end
  end
end
