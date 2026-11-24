# frozen_string_literal: true

require_relative "mcp_copy/copy"
require_relative "mcp_copy/current_copy"

module RecordingStudioIdentity
  # Registers Identity on Recording Studio MCP when that gem is loaded.
  # This gem does not depend on it. Hosts that skip MCP keep the UI and API only.
  module McpCopy
    include Copy
    include CurrentCopy

    TYPE = Api::TYPE
    CRUD_OPERATIONS = {
      list: :index,
      show: :show,
      create: :create,
      update: :update
    }.freeze
    ACTIONS = %i[identity_set_image identity_remove_image].freeze
    CURRENT = %i[show_current_identity update_current_identity].freeze
    TOOL_NAMES = {
      list: "list_identities",
      show: "show_identity",
      create: "create_identity",
      update: "update_identity",
      show_current_identity: "show_current_identity",
      update_current_identity: "update_current_identity",
      identity_set_image: "identity_set_image",
      identity_remove_image: "identity_remove_image"
    }.freeze

    module_function

    def register!
      return unless defined?(::RecordingStudioMcp)

      register_types
      register_crud
      register_current
      register_actions
    end

    def tool_names
      (CRUD_OPERATIONS.keys + CURRENT + ACTIONS).map { |name| tool_name(name) }
    end

    def tool_name(name)
      TOOL_NAMES.fetch(name.to_sym)
    end

    def register_types
      return unless ::RecordingStudioMcp.respond_to?(:register_type)

      ::RecordingStudioMcp.register_type(type: TYPE, description: TYPE_DESCRIPTION)
    end

    def register_crud
      return unless ::RecordingStudioMcp.respond_to?(:register_tool)

      CRUD_OPERATIONS.each { |name, api_operation| register_crud_tool(name, api_operation) }
    end

    def register_actions
      return unless ::RecordingStudioMcp.respond_to?(:register_tool)

      ACTIONS.each { |action| register_action_tool(action) }
    end

    def register_current
      return unless ::RecordingStudioMcp.respond_to?(:register_tool)

      CURRENT.each { |name| register_current_tool(name) }
    end

    def register_crud_tool(name, api_operation)
      copy = CRUD_COPY.fetch(name)
      ::RecordingStudioMcp.register_tool(
        name: tool_name(name),
        type: TYPE,
        operation: api_operation,
        title: copy.fetch(:title),
        description: copy.fetch(:description),
        input: copy.fetch(:input),
        output: copy.fetch(:output)
      )
    end

    def register_current_tool(name)
      copy = CURRENT_COPY.fetch(name)
      ::RecordingStudioMcp.register_tool(
        name: tool_name(name),
        endpoint: name,
        title: copy.fetch(:title),
        description: copy.fetch(:description),
        input: copy.fetch(:input),
        output: copy.fetch(:output)
      )
    end

    def register_action_tool(action)
      copy = ACTION_COPY.fetch(action)
      ::RecordingStudioMcp.register_tool(
        name: tool_name(action),
        type: TYPE,
        action: action,
        title: copy.fetch(:title),
        description: copy.fetch(:description),
        input: copy.fetch(:input),
        output: copy.fetch(:output)
      )
    end
  end
end
