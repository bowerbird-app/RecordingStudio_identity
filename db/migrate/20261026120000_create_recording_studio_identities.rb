# frozen_string_literal: true

class CreateRecordingStudioIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_identities, id: :uuid do |t|
      t.string :name, null: false
      t.string :kind, null: false
      t.text :description
      t.string :website_url
      t.datetime :created_at, null: false

      t.index :kind, name: "index_recording_studio_identities_on_kind"
    end
  end
end
