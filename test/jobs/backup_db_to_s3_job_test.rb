require "test_helper"
require "aws-sdk-s3"

class BackupDbToS3JobTest < ActiveJob::TestCase
  setup do
    @previous_s3_config = Aws.config[:s3]
    Aws.config[:s3] = { stub_responses: true }
  end

  teardown do
    Aws.config[:s3] = @previous_s3_config
  end

  test "uploads a gzipped backup to S3 and records it" do
    credentials = {
      aws: {
        s3_access_key_id: "test",
        s3_secret_access_key: "test",
        s3_region: "us-east-1",
        s3_db_backup_bucket: "backups-test"
      }
    }

    assert_difference -> { DbBackup.count }, 1 do
      with_credentials(credentials) { BackupDbToS3Job.perform_now }
    end

    assert_match(/\Atest\.sqlite3\..*\.backup\.gz\z/, DbBackup.last.key)

    leftovers = Dir.glob(Rails.root.join("storage", "test.sqlite3.*.backup*"))
    assert_empty leftovers, "expected backup artifacts to be cleaned up, found: #{leftovers}"
  end

  private

  def with_credentials(hash)
    Rails.application.define_singleton_method(:credentials) { hash }
    yield
  ensure
    Rails.application.singleton_class.remove_method(:credentials)
  end
end
