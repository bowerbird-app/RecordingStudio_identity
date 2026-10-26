# frozen_string_literal: true

module RecordingStudioIdentity
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioIdentity

    class << self
      def apply_model_extensions(target)
        apply_extensions(target, extensions_for(:model, extension_keys_for(target)))
      end

      def apply_controller_extensions(target)
        apply_extensions(target, extensions_for(:controller, extension_keys_for(target)))
      end

      private

      def extensions_for(kind, names)
        hooks = RecordingStudioIdentity.configuration.hooks
        Array(names).flat_map do |name|
          if kind == :model
            hooks.model_extensions_for(name)
          else
            hooks.controller_extensions_for(name)
          end
        end
      end

      def apply_extensions(target, extensions)
        return unless target

        applied = target.instance_variable_get(:@recording_studio_identity_applied_extensions) || identity_hash

        extensions.flatten.compact.each do |extension|
          next if applied[extension]

          target.class_eval(&extension)
          applied[extension] = true
        end

        target.instance_variable_set(:@recording_studio_identity_applied_extensions, applied)
      end

      def extension_keys_for(target)
        names = [target.name, target.name&.demodulize].compact.uniq
        names.map(&:to_sym)
      end

      def identity_hash
        {}.compare_by_identity
      end
    end

    # Run before_initialize hooks
    initializer "recording_studio_identity.before_initialize", before: "recording_studio_identity.load_config" do |_app|
      RecordingStudioIdentity.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_identity.load_config" do |app|
      # Load config/recording_studio_identity.yml via Rails config_for if present
      if app.respond_to?(:config_for)
        begin
          yaml = begin
            app.config_for(:recording_studio_identity)
          rescue StandardError
            nil
          end
          RecordingStudioIdentity.configuration.merge!(yaml) if yaml.respond_to?(:each)
        rescue StandardError => _e
          # ignore load errors; host app can provide initializer overrides
        end
      end

      # Merge Rails.application.config.x.recording_studio_identity if present
      if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_identity)
        xcfg = app.config.x.recording_studio_identity
        if xcfg.respond_to?(:to_h)
          RecordingStudioIdentity.configuration.merge!(xcfg.to_h)
        else
          begin
            # try converting OrderedOptions
            hash = {}
            xcfg.each_pair { |k, v| hash[k] = v } if xcfg.respond_to?(:each_pair)
            RecordingStudioIdentity.configuration.merge!(hash) if hash&.any?
          rescue StandardError => _e
            # ignore
          end
        end
      end

      # Run on_configuration hooks after config is loaded
      RecordingStudioIdentity.configuration.hooks.run(:on_configuration, RecordingStudioIdentity.configuration)
    end

    # Run after_initialize hooks
    initializer "recording_studio_identity.after_initialize", after: "recording_studio_identity.load_config" do |_app|
      RecordingStudioIdentity.configuration.hooks.run(:after_initialize, self)
    end

    # Apply model extensions when models are loaded
    initializer "recording_studio_identity.apply_model_extensions" do
      config.to_prepare do
        next unless defined?(ActiveRecord::Base)

        ActiveRecord::Base.descendants.each do |model|
          next if model.abstract_class?

          RecordingStudioIdentity::Engine.apply_model_extensions(model)
        end
      end
    end

    # Apply controller extensions
    initializer "recording_studio_identity.apply_controller_extensions" do
      config.to_prepare do
        next unless defined?(ActionController::Base)

        ActionController::Base.descendants.each do |controller|
          RecordingStudioIdentity::Engine.apply_controller_extensions(controller)
        end
      end
    end

    initializer "recording_studio_identity.recordable_types", after: :load_config_initializers do
      registered = RecordingStudio.configuration.recordable_types.map(&:to_s)
      needed = [
        IMAGE_TYPE,
        "RecordingStudioAttachable::Library",
        "RecordingStudioAttachable::Placement",
        IDENTITY_TYPE
      ]
      RecordingStudio.configuration.recordable_types = (registered + needed).uniq
      RecordingStudio::DelegatedTypeRegistrar.apply!
    end

    initializer "recording_studio_identity.slots" do
      config.to_prepare do
        RecordingStudioIdentity::Identity.table_name
        recording = RecordingStudio::Recording
        recording.include(Slots::Validation) unless recording.include?(Slots::Validation)

        unless RecordingStudio.capability_enabled?(:trashable, for: IMAGE_TYPE)
          RecordingStudioAttachable::Attachment.include(RecordingStudio::Capabilities::Trashable.to)
        end

        Slots.verify!
      end
    end

    initializer "recording_studio_identity.display_helper" do
      ActiveSupport.on_load(:action_view) { include RecordingStudioIdentity::DisplayHelper }
    end
  end
end
