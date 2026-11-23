# frozen_string_literal: true

return unless defined?(RecordingStudioMcp)

RecordingStudioMcp.configure do |config|
  config.mcp_mount_path = "/recording_studio_mcp"
  config.oauth_protected_resource_path = "/.well-known/oauth-protected-resource/recording_studio_mcp"
  config.oauth_engine_mount_path = "/recording_studio_oauth"
  config.list_parent_id_types = [RecordingStudioIdentity::Api::TYPE]
end

include_identity_mcp = lambda do |*|
  next unless defined?(::RecordingStudioMcp)
  next unless RecordingStudioMcp.respond_to?(:register_server)

  RecordingStudioIdentity::McpCopy.register!
  names = RecordingStudioIdentity::McpCopy.tool_names
  RecordingStudioMcp.register_server(:public, api: :public) do
    include_tools(*names)
  end
  RecordingStudioMcp.register_server(:operations, api: :operations, allow_sensitive: true) do
    include_tools(*names)
  end
end

Rails.application.config.to_prepare(&include_identity_mcp)
Rails.application.config.after_initialize(&include_identity_mcp)
