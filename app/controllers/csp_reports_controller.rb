class CspReportsController < ApplicationController
  # Browsers POST application/csp-report with no CSRF token, no session.
  skip_before_action :verify_authenticity_token

  def create
    report = request.body.read(8192)
    Rails.logger.warn("CSP violation: #{report}") if report.present?
    head :no_content
  end
end
