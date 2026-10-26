# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_identity/migrations/migrations_generator"

class MigrationsGeneratorTest < Minitest::Test
  def test_copies_the_identities_migration
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "db/migrate"))
      generator = build_generator(dir)

      generator.stub(:sleep, nil) do
        generator.copy_migrations
      end

      copied = Dir.glob(File.join(dir, "db/migrate/*_create_recording_studio_identities.rb"))
      assert_equal 1, copied.size
      source = File.read(copied.first)
      assert_includes source, "create_table :recording_studio_identities"
      assert_includes source, "index_recording_studio_identities_on_kind"
    end
  end

  def test_skips_an_existing_identities_migration
    Dir.mktmpdir do |dir|
      migrate_dir = File.join(dir, "db/migrate")
      FileUtils.mkdir_p(migrate_dir)
      existing = File.join(migrate_dir, "20200101000000_create_recording_studio_identities.rb")
      File.write(existing, "# existing\n")
      generator = build_generator(dir)

      generator.stub(:sleep, nil) do
        generator.copy_migrations
      end

      copied = Dir.glob(File.join(migrate_dir, "*_create_recording_studio_identities.rb"))
      assert_equal [existing], copied
      assert_equal "# existing\n", File.read(existing)
    end
  end

  private

  def build_generator(destination_root)
    RecordingStudioIdentity::Generators::MigrationsGenerator.new(
      [],
      {},
      destination_root: destination_root
    )
  end
end
