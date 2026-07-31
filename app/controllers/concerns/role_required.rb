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
end
