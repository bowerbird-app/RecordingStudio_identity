# frozen_string_literal: true

require_relative "errors"
require_relative "../mcp_copy/current_copy"

module RecordingStudioIdentity
  module Api
    module CurrentIdentity
      NO_ROOT = "This client has no root."
      NO_IDENTITY = "This root has no identity."
      MANY_IDENTITIES =
        "This root allows many identities. Pass an id to show_identity or update_identity."
      WRITABLE = %i[name description website_url].freeze
      PATH = "current_identity"

      module_function

      def show(context)
        identity = load!(context)
        context.access_grant.authorize!(recording: identity, role: :view)
        serialize(identity, context)
      end

      def update(context)
        identity = load!(context)
        context.access_grant.authorize!(recording: identity, role: :edit)
        Errors.wrap do
          changed = RecordingStudioIdentity.update(
            identity, actor: context.access_grant.actor, **fields(context)
          )
          serialize(changed, context)
        end
      end

      def register!(api)
        register_endpoint(api, :show_current_identity, :get, method(:show), show_contract)
        register_endpoint(api, :update_current_identity, :patch, method(:update), update_contract)
      end

      def load!(context)
        root = context.root_recording
        raise ::RecordingStudioApi::NotFoundError, NO_ROOT if root.nil?

        found = RecordingStudioIdentity.identity(root)
        raise ::RecordingStudioApi::InvalidActionInputError, NO_IDENTITY if found.nil?

        found
      rescue RecordingStudioIdentity::ManyIdentitiesAllowed
        raise ::RecordingStudioApi::InvalidActionInputError, MANY_IDENTITIES
      rescue RecordingStudioIdentity::ParentNotAllowed => e
        raise ::RecordingStudioApi::NotFoundError, e.message
      end

      def fields(context)
        raw = context.params
        hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
        hash.symbolize_keys.slice(*WRITABLE)
      end

      def serialize(recording, context)
        ::RecordingStudioApi::Serializers::ResourceRecordingSerializer.call(
          recording,
          version: ::RecordingStudioApi.default_api_version(api: context.api_key),
          api: context.api_key
        )
      end

      def register_endpoint(api, name, verb, handler, contract)
        return if ::RecordingStudioApi.registered_endpoint(name, api: api)

        ::RecordingStudioApi.register_endpoint(
          name,
          api: api,
          http_verb: verb,
          path: PATH,
          handler: handler,
          openapi: openapi_for(name),
          input_contract: contract
        )
      end

      def openapi_for(name)
        copy = McpCopy::CurrentCopy::CURRENT_COPY.fetch(name)
        {
          summary: copy.fetch(:title),
          description: copy.fetch(:description),
          tags: DocsTag.list
        }
      end

      def show_contract
        { reject_unknown: true, fields: {} }
      end

      def update_contract
        {
          reject_unknown: true,
          fields: {
            name: { type: :string },
            description: { type: :string },
            website_url: { type: :string }
          }
        }
      end

      class DocsTag
        def self.list
          @list ||= new
        end

        def to_ary
          [RecordingStudioIdentity.configuration.current_identity_tag]
        end

        def as_json(*)
          to_ary
        end

        def to_json(*)
          JSON.generate(to_ary)
        end
      end
    end
  end
end
