class AssetsController < ApplicationController
  include PinnedToDefaultLocale
  
  # Private
  
  before_action :login_required
  
  layout 'admin'

  def index
    scope = params[:q].present? ? Asset.editor_search(params[:q]) : Asset.all
    @assets = scope.order("id DESC").paginate(:page => params[:page], :per_page => 20)
  end

  # GET /assets/1
  # GET /assets/1.xml
  def show
    @asset = Asset.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @asset }
    end
  end

  # GET /assets/new
  # GET /assets/new.xml
  def new
    @asset = Asset.new
    @attach_node = Node.not_in_trash.find_by(:id => params[:node_id]) if params[:node_id].present?

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @asset }
    end
  end

  # GET /assets/1/edit
  def edit
    @asset = Asset.find(params[:id])
  end

  # POST /assets
  # POST /assets.xml
  def create
    @asset = Asset.new(asset_params)
    attach_node = Node.not_in_trash.find_by(:id => params[:node_id]) if params[:node_id].present?

    respond_to do |format|
      if @asset.save
        flash[:notice] = t("flash.assets.created")
        NodeAction.record!(:participants => [@asset], :user => current_user,
                            :action => "asset_create",
                            :asset_name   => @asset.name,
                            :content_type => @asset.upload_content_type,
                            :path         => @asset.upload.url.sub(/\?\d+$/, ""))
        attach_to(attach_node) if attach_node
        format.html { redirect_to(@asset) }
        format.xml  { render :xml => @asset, :status => :created, :location => @asset }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @asset.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /assets/1
  # PUT /assets/1.xml
  def update
    @asset = Asset.find(params[:id])

    respond_to do |format|
      if @asset.update(asset_params)
        flash[:notice] = t("flash.assets.updated")
        format.html { redirect_to(@asset) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @asset.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /assets/1
  # DELETE /assets/1.xml
  def destroy
    @asset = Asset.find(params[:id])
    @asset.destroy_witnessed!(:user => current_user)

    respond_to do |format|
      format.html { redirect_to(assets_url) }
      format.xml  { head :ok }
    end
  rescue ActiveRecord::RecordInvalid => e
    flash[:error] = e.record.errors.full_messages.to_sentence
    respond_to do |format|
      format.html { redirect_to(asset_path(@asset)) }
      format.xml  { head :forbidden }
    end
  end

  private

    def asset_params
      params.require(:asset).permit(:name, :upload, :creator, :source_url, :license_key)
    end

    def attach_to node
      result = node.attach_asset!(@asset, :user => current_user,
                                   :headline => params[:headline].present?)
      flash[:notice] =
        if result[:attached].zero?
          t("flash.assets.already_attached", :title => node.title)
        else
          t("flash.assets.attached", :title => node.title)
        end
      case result[:headline]
      when :set           then flash[:notice] += " " + t("flash.common.now_headline")
      when :kept_existing then flash[:headline_kept_path] = node_path(node)
      when :not_eligible  then flash[:error] = t("flash.common.headline_ineligible")
      end
    rescue LockedByAnotherUser
      flash[:locked_by]        = node.lock_owner&.login
      flash[:locked_node_path] = node_path(node)
    end
end
