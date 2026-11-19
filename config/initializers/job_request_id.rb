module JobRequestId
  def serialize
    super.merge("request_id" => enqueuing_request_id || SemanticLogger.named_tags[:request_id])
  end

  def deserialize(job_data)
    super
    @enqueuing_request_id = job_data["request_id"]
  end

  def perform_now
    return super if enqueuing_request_id.nil?

    SemanticLogger.named_tagged(request_id: enqueuing_request_id) { super }
  end

  private

  attr_reader :enqueuing_request_id
end

ActiveSupport.on_load(:active_job) { include JobRequestId }
