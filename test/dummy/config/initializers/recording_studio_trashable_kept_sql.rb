# frozen_string_literal: true

# Trashable 0.16 removed this class method. Accessible 0.41, API 0.23, and Admin 2.13
# still call it. Identity reads Recording.kept. Drop this when those gems do too.
Rails.application.reloader.to_prepare do
  RecordingStudio::Recording.define_singleton_method(:recording_studio_trashable_kept_sql) do |table = "recording_studio_recordings"|
    RecordingStudio.kept_sql(table)
  end
end
