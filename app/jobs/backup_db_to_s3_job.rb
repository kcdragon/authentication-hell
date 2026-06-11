require "aws-sdk-s3"

class BackupDbToS3Job < ApplicationJob
  queue_as :default

  def perform
    db_directory = Rails.root.join("storage")
    primary_db_path = db_directory.join("#{Rails.env}.sqlite3")

    timestamp = Time.now.strftime("%Y-%m-%d-%H-%M-%S")
    backup_path = db_directory.join("#{Rails.env}.sqlite3.#{timestamp}.backup")

    # SQLite's .backup yields a consistent copy even while the DB is in use.
    system("sqlite3", primary_db_path.to_s, ".backup '#{backup_path}'", exception: true)
    system("gzip", backup_path.to_s, exception: true)

    gzipped_path = Rails.root.join("storage", "#{backup_path.basename}.gz")
    key = gzipped_path.basename.to_s

    File.open(gzipped_path, "rb") do |file|
      s3_client.put_object(bucket: backup_bucket, key:, body: file)
    end

    DbBackup.create!(key:, occurred_at: Time.now)
  ensure
    File.delete(gzipped_path) if gzipped_path && File.exist?(gzipped_path)
  end

  private

  def s3_client
    Aws::S3::Client.new(
      access_key_id: Rails.application.credentials.dig(:aws, :s3_access_key_id),
      secret_access_key: Rails.application.credentials.dig(:aws, :s3_secret_access_key),
      region: Rails.application.credentials.dig(:aws, :s3_region)
    )
  end

  def backup_bucket
    Rails.application.credentials.dig(:aws, :s3_db_backup_bucket)
  end
end
