# frozen_string_literal: true

require_relative "lib/recording_studio_identity/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_identity"
  spec.version     = RecordingStudioIdentity::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_identity"
  spec.summary     = "Public identities for Recording Studio"
  spec.description = "A Recording Studio addon for public identities (people, companies, brands, and organisations) " \
                     "mounted under any recording that enables the identities capability."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_identity"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_identity/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "flat_pack", ">= 0.1.213"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
  spec.add_dependency "recording_studio_accessible", "~> 0.18"
  spec.add_dependency "recording_studio_attachable", "~> 0.15"
  spec.add_dependency "recording_studio_trashable", "~> 0.10"
end
