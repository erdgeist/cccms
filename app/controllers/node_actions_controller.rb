class NodeActionsController < ApplicationController

  before_action :login_required

  layout 'admin'

  def index
    @actions = NodeAction.order(:occurred_at => :desc, :id => :desc)
    @actions = @actions.where(:node_id => params[:node_id]) if params[:node_id].present?
    @actions = @actions.where(:user_id => params[:user_id]) if params[:user_id].present?
    @actions = @actions.includes(:node, :user)
                       .paginate(:page => params[:page], :per_page => 50)
  end
end
