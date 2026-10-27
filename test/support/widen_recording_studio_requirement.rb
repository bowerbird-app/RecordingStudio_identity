# frozen_string_literal: true

# Git tags we pin still ship gemspecs that reject Recording Studio 6.1.0
# or Trashable 0.12.0. Bundler evaluates those gemspecs in this process,
# so the floor has to move before Bundler.setup.
module WidenRecordingStudioRequirement
  FLOORS = {
    "recording_studio" => Gem::Version.new("6.1.0"),
    "recording_studio_trashable" => Gem::Version.new("0.12.0")
  }.freeze

  module Specification
    def add_dependency(name, *requirements)
      super(name, *WidenRecordingStudioRequirement.widen(name, requirements))
    end
  end

  def self.widen(name, requirements)
    floor = FLOORS[name.to_s]
    return requirements unless floor

    requirement = Gem::Requirement.new(requirements)
    return requirements if requirement.satisfied_by?(floor)

    [">= #{floor}"]
  end

  def self.install!
    return if Gem::Specification.ancestors.include?(Specification)

    Gem::Specification.prepend(Specification)
  end
end

WidenRecordingStudioRequirement.install!
