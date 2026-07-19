# CSP violation reports get their own file, independent of config.logger.
CSP_LOGGER = Rails.env.production? ?
  ActiveSupport::Logger.new(Rails.root.join("log", "csp_violations.log")) :
  Rails.logger
