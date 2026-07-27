class NodeActionsController < ApplicationController
  include PinnedToDefaultLocale

  before_action :login_required

  layout 'admin'

  def index
    @actions = NodeAction.order(:occurred_at => :desc, :id => :desc)
    if params[:node_id].present?
      @actions = @actions.joins(:action_participants)
                         .where(:action_participants => { :subject_type => "Node",
                                                          :subject_id   => params[:node_id] })
    end
    if params[:asset_id].present?
      @actions = @actions.joins(:action_participants)
                         .where(:action_participants => { :subject_type => "Asset",
                                                          :subject_id   => params[:asset_id] })
    end
    @actions = @actions.where(:user_id => params[:user_id]) if params[:user_id].present?
    @actions = @actions.includes(:node, :user)
                       .paginate(:page => params[:page], :per_page => 50)
  end
end
