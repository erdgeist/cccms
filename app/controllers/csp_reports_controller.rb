class CspReportsController < ApplicationController
  # Browsers POST application/csp-report with no CSRF token, no session.
  skip_before_action :verify_authenticity_token

  def create
    request.body.rewind if request.body.respond_to?(:rewind)
    raw = request.body.read(8192)
    raw = request.raw_post if raw.blank?

    report = (JSON.parse(raw)["csp-report"] rescue nil)

    if report
      directive = report["effective-directive"] || report["violated-directive"]
      at = (URI.parse(report["document-uri"]).path rescue "unparsed")
      CSP_LOGGER.warn("CSP violation: #{directive} blocked=#{report['blocked-uri']} at=#{at}")
    else
      CSP_LOGGER.warn("CSP violation: unparseable report (#{raw.to_s.bytesize} bytes)")
    end

    head :no_content
  end
end
