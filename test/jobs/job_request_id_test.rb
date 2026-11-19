require "test_helper"

class JobRequestIdTest < ActiveJob::TestCase
  class RecordsRequestIdJob < ApplicationJob
    cattr_accessor :request_id_seen

    def perform
      self.class.request_id_seen = SemanticLogger.named_tags[:request_id]
    end
  end

  test "carries the enqueuing request's id into the job's log lines" do
    serialized = SemanticLogger.named_tagged(request_id: "req-123") { RecordsRequestIdJob.new.serialize }

    ActiveJob::Base.execute(serialized)

    assert_equal "req-123", RecordsRequestIdJob.request_id_seen
  end

  test "runs without a request id when enqueued outside a request" do
    RecordsRequestIdJob.request_id_seen = "stale"

    ActiveJob::Base.execute(RecordsRequestIdJob.new.serialize)

    assert_nil RecordsRequestIdJob.request_id_seen
  end

  test "keeps the original request id when a job is re-enqueued for a retry" do
    serialized = SemanticLogger.named_tagged(request_id: "req-123") { RecordsRequestIdJob.new.serialize }
    retried = RecordsRequestIdJob.deserialize(serialized)

    assert_equal "req-123", retried.serialize["request_id"]
  end

  test "applies to jobs that don't inherit ApplicationJob, such as mail deliveries" do
    SemanticLogger.named_tagged(request_id: "req-456") { PasswordsMailer.reset(users(:one)).deliver_later }

    assert_equal "req-456", enqueued_jobs.last.fetch("request_id")
  end
end
