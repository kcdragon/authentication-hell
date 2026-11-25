Rails.application.config.after_initialize do
  require "action_controller/log_subscriber"
  require "action_view/log_subscriber"
  require "action_mailer/log_subscriber"
  require "active_record/log_subscriber"
  require "active_job/log_subscriber"

  [ ActionController::LogSubscriber, ActionView::LogSubscriber, ActionMailer::LogSubscriber,
    ActiveRecord::LogSubscriber, ActiveJob::LogSubscriber ].each do |replaced_by_semantic_logger|
    ActiveSupport.event_reporter.unsubscribe(replaced_by_semantic_logger)
  end
end
