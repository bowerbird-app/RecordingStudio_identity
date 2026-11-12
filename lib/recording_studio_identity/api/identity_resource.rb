# frozen_string_literal: true

require_relative "errors"

module RecordingStudioIdentity
  module Api
    module IdentityResource
      module_function

      def serialize(recording, context)
        ::RecordingStudioApi::Serializers::ResourceRecordingSerializer.call(
          recording,
          version: context.api_version,
          api: context.api_key
        )
      end

      def payload(context)
        ::RecordingStudioApi::RequestPayload.call(context)
      end

      def parent_recording(context)
        parent_id = context.parent_id.presence || payload(context)[:parent_id] || payload(context)["parent_id"]
        if parent_id.blank?
          raise ::RecordingStudioApi::InvalidActionInputError, "parent_id is required for #{Api::TYPE}"
        end

        parent = context.scoped_recordings.find_by(id: parent_id)
        raise ::RecordingStudioApi::NotFoundError, "Parent resource was not found in this API scope" if parent.nil?

        parent
      end

      def recording(context)
        Errors.wrap do
          identity = RecordingStudioIdentity.find(context.id)
          visible = context.scoped_recordings.find_by(id: identity.id)
          raise RecordingStudioIdentity::NotFound, "No identity #{context.id.inspect}" if visible.nil?

          identity
        end
      end

      def fields(context)
        raw = payload(context)
        symbolized = raw.respond_to?(:deep_symbolize_keys) ? raw.deep_symbolize_keys : raw.to_h.transform_keys(&:to_sym)
        symbolized.slice(*Api::FIELDS)
      end

      class Index
        def self.call(context)
          Errors.wrap { new(context).payload }
        end

        def initialize(context)
          @context = context
        end

        def payload
          parent = IdentityResource.parent_recording(@context)
          @context.access_grant.authorize!(recording: parent, role: :view)
          pagination = ::RecordingStudioApi::Services::PaginateResourceCollection.call(**pagination_args(parent))
          raise ::RecordingStudioApi::InvalidPaginationTokenError, pagination.error if pagination.failure?

          { json: pagination.value.response_body { |recordings, meta| collection(recordings, meta) } }
        end

        def pagination_args(parent)
          {
            relation: RecordingStudio::Recording.unscoped.where(
              id: RecordingStudioIdentity.identities(parent).map(&:id)
            ),
            resource: @context.resource_name,
            recordable_type: @context.recordable_type,
            api: @context.api_key,
            scope_key: "client:#{@context.api_client.id}"
          }.merge(page_params)
        end

        def page_params
          params = @context.params
          {
            limit: params[:limit],
            pagination_token: params[:pagination_token],
            sort: params[:sort],
            order: params[:order],
            count: params[:count]
          }
        end

        def collection(recordings, meta)
          {
            resource: @context.resource_name,
            type: @context.recordable_type.demodulize,
            records: recordings.map { |recording| IdentityResource.serialize(recording, @context) },
            meta: meta
          }
        end
      end

      class Show
        def self.call(context)
          Errors.wrap do
            identity = IdentityResource.recording(context)
            context.access_grant.authorize!(recording: identity, role: :view)
            { json: IdentityResource.serialize(identity, context) }
          end
        end
      end

      class Create
        def self.call(context)
          Errors.wrap { new(context).create }
        end

        def initialize(context)
          @context = context
        end

        def create
          parent = IdentityResource.parent_recording(@context)
          @context.access_grant.authorize!(recording: parent, role: :edit)
          identity = RecordingStudioIdentity.create(
            parent,
            actor: @context.actor,
            idempotency_key: @context.idempotency_key,
            **IdentityResource.fields(@context)
          )
          { json: IdentityResource.serialize(identity, @context), status: :created }
        end
      end

      class Update
        def self.call(context)
          Errors.wrap do
            identity = IdentityResource.recording(context)
            context.access_grant.authorize!(recording: identity, role: :edit)
            updated = RecordingStudioIdentity.update(
              identity,
              actor: context.actor,
              **IdentityResource.fields(context)
            )
            { json: IdentityResource.serialize(updated, context) }
          end
        end
      end
    end
  end
end
