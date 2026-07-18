# Every controller-level exception (the 500s) in one lean file,
# independent of the base log level -- log/production.log can stay
# quiet without losing error visibility.
if Rails.env.production?
  error_logger = ActiveSupport::Logger.new(Rails.root.join("log", "errors.log"))

  ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*, payload|
    if (exception = payload[:exception_object])
      status = ActionDispatch::ExceptionWrapper.status_code_for_exception(exception.class.name)
      next if status < 500

      error_logger.error(
        "#{Time.now.iso8601} [#{status}] #{payload[:controller]}##{payload[:action]} #{payload[:path]} " \
        "-- #{exception.class}: #{exception.message}\n    " +
        Array(exception.backtrace).first(5).join("\n    ")
      )
    end
  end
end

