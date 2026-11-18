# frozen_string_literal: true

require "uri"

module RecordingStudioIdentity
  # A host return path is a relative path on this host, or nothing.
  module ReturnTo
    UNSAFE_TEXT = %r{[[:cntrl:]]|\s|\\|%5c|\A/%2f}i
    private_constant :UNSAFE_TEXT

    def self.safe(candidate, configuration: RecordingStudioIdentity.configuration)
      return unless candidate.is_a?(String)
      return if candidate.blank?
      return unless relative_path?(candidate)

      checker = configuration.allow_return_to
      candidate if checker.nil? || checker.call(candidate)
    end

    def self.relative_path?(candidate)
      return false unless single_slash?(candidate)

      uri = parsed_uri(candidate)
      return false if uri.nil?

      same_host_path?(uri)
    end
    private_class_method :relative_path?

    def self.single_slash?(candidate)
      candidate.start_with?("/") && !candidate.start_with?("//") && !candidate.match?(UNSAFE_TEXT)
    end
    private_class_method :single_slash?

    def self.parsed_uri(candidate)
      URI.parse(candidate)
    rescue URI::InvalidURIError
      nil
    end
    private_class_method :parsed_uri

    def self.same_host_path?(uri)
      path = uri.path.to_s
      uri.scheme.nil? && uri.host.nil? && path.start_with?("/") && !path.include?(":")
    end
    private_class_method :same_host_path?
  end
end
