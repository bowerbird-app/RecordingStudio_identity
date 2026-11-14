# frozen_string_literal: true

# Trashable 0.16 removed this class method. API 0.23 and Admin 2.13 still call it.
# Accessible 0.42 does not. Identity reads Recording.kept. Drop this when API and Admin do too.
Rails.application.reloader.to_prepare do
  RecordingStudio::Recording.define_singleton_method(:recording_studio_trashable_kept_sql) do |table = "recording_studio_recordings"|
    RecordingStudio.kept_sql(table)
  end
end
