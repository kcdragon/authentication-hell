require "test_helper"

class RequestLoggingTest < ActionDispatch::IntegrationTest
  setup do
    @log = StringIO.new
    @appender = SemanticLogger.add_appender(io: @log, level: :info)
    @previous_level = Rails.logger.level
    Rails.logger.level = :info
  end

  teardown do
    SemanticLogger.remove_appender(@appender)
    Rails.logger.level = @previous_level
  end

  test "a request is logged once, by semantic logger" do
    get root_path
    assert_equal [ "Completed #show" ], completed_lines.map { it[/Completed #?\S+/] }
  end

  test "a signed-out request to a signed-in page logs without errors" do
    assert_no_error_reported do
      get user_path
    end
    assert_redirected_to new_session_path
    assert_equal 1, completed_lines.size
  end

  private

  def completed_lines
    SemanticLogger.flush
    @log.string.lines.grep(/ Completed /)
  end
end
