# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @studio = root_recording_for(Workspace.find_by(name: "Studio Workspace"))
    @client = root_recording_for(Workspace.find_by(name: "Client Workspace"))
    @agency = root_recording_for(Agency.find_by(name: "Harbour Agency"))
    project = Project.find_by(name: "Harbour fit-out")
    @project = project && RecordingStudio::Recording.find_by(recordable: project)
  end

  private

  def root_recording_for(recordable)
    return if recordable.nil?

    RecordingStudio.root_recording_for(recordable)
  end
end
