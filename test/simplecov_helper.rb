# frozen_string_literal: true

return if ENV["DISABLE_SIMPLECOV"] == "true"

begin
  require "simplecov"
rescue LoadError
  return
end

return if SimpleCov.instance_variable_get(:@recording_studio_identity_started)

SimpleCov.instance_variable_set(:@recording_studio_identity_started, true)
SimpleCov.root(File.expand_path("..", __dir__))
SimpleCov.coverage_dir(File.expand_path("../coverage", __dir__))
SimpleCov.command_name("#{ENV.fetch('SIMPLECOV_COMMAND_NAME', 'minitest')}-#{Process.pid}")
SimpleCov.merge_timeout(3600)

SimpleCov.start do
  enable_coverage :branch
  skip "/test/"
  skip "/config/"
  skip "/db/"
  skip "/docs/"
end
