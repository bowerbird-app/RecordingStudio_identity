# frozen_string_literal: true

require_relative "api/identity_resource"
require_relative "api/image_actions"

module RecordingStudioIdentity
  module Api
    TYPE = "RecordingStudioIdentity::Identity"
    FIELDS = %i[name kind description website_url].freeze

    module_function

    def register!
      return unless defined?(::RecordingStudioApi)

      ::RecordingStudioApi.configuration.each_api { |api| register_api(api.name) }
    end

    def register_api(api)
      register_type(api)
      register_resource_handlers(api)
      ImageActions.register!(api)
    end

    def register_type(api)
      return if ::RecordingStudioApi.recordable_registration_for(TYPE, api:)

      ::RecordingStudioApi.register_recordable_type_api(TYPE, **type_options(api))
    end

    def type_options(api)
      {
        api:, operations: %i[index show create update], auto_capability_actions: false,
        capability_actions: %i[identity_set_image identity_remove_image], serializer: method(:serialize_fields),
        output_keys: FIELDS, writable_attributes: FIELDS, immutable_fields: %i[kind],
        openapi: openapi_docs
      }
    end

    def register_resource_handlers(api)
      {
        index: IdentityResource::Index,
        show: IdentityResource::Show,
        create: IdentityResource::Create,
        update: IdentityResource::Update
      }.each do |action, handler|
        next if ::RecordingStudioApi.resource_handler(TYPE, action, api:)

        ::RecordingStudioApi.register_resource_handler(TYPE, action, api:, handler:)
      end
    end

    def serialize_fields(identity, **)
      FIELDS.index_with { |field| identity.public_send(field) }
    end

    def kind_values
      RecordingStudioIdentity.categories.map(&:key)
    end

    def openapi_docs
      { details_schema: details_schema, **operation_docs }
    end

    def details_schema
      {
        type: "object",
        properties: {
          name: { type: "string" },
          kind: { type: "string", enum: kind_values },
          description: { type: "string" },
          website_url: { type: "string" }
        }
      }
    end

    def operation_docs
      { index: index_docs, show: show_docs, create: create_docs, update: update_docs }
    end

    def index_docs
      docs("Identity - Index",
           "Lists identities under a parent. Needs Accessible view on that parent. Pass parent_id. " \
           "Paginate with limit and pagination_token.")
    end

    def show_docs
      docs("Identity - Show",
           "Returns one identity. Needs Accessible view on it. Identities outside this workspace are not found.")
    end

    def create_docs
      docs("Identity - Create",
           "Adds an identity under a parent. Needs Accessible edit on that parent. kind must be a " \
           "configured category. name is required. description and website_url are optional.")
    end

    def update_docs
      docs("Identity - Update",
           "Revises an identity. Needs Accessible edit on it. name, description, and website_url may " \
           "change. kind cannot.")
    end

    def docs(summary, description)
      { summary:, description: }
    end
  end
end
