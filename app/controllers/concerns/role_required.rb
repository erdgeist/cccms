# Controller-level role gates, for surfaces that are not nodes and so cannot
# be reached by Node#restricted?. The node gates live in the models, since
# those verbs are callable from rake tasks; these are HTTP-only.
module RoleRequired
  extend ActiveSupport::Concern

  private

    def require_redaktion
      return if current_user&.redaktion?
      deny_role_access(:redaktion_required)
    end

    def require_admin
      return if current_user&.is_admin?
      deny_role_access(:admin_required)
    end

    def deny_role_access(key)
      flash[:error] = t("flash.common.#{key}")
      redirect_to admin_path
    end

    # require_admin must precede this in the filter chain, so a non-admin is
    # denied by role before elevation is ever considered.
    def require_elevation
      return if elevated?

      session[:elevation_return_to] = request.fullpath
      redirect_to new_elevation_path
    end
end
