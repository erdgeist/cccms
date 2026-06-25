class MenuItemsController < ApplicationController

  # Private

  before_action :login_required
  
  layout 'admin'
  
  def index
    @menu_items = MenuItem.order("position ASC").all
  end

  def show
  end

  def new
    @menu_item = MenuItem.new menu_item_params
  end

  def create
    if MenuItem.create( menu_item_params )
      redirect_to menu_items_path
    else
      render :new
    end
  end

  def edit
    @menu_item = MenuItem.find( params[:id] )
  end

  def update
    @menu_item = MenuItem.find( params[:id] )
    
    if @menu_item.update( menu_item_params )
      redirect_to menu_items_path
    else
      render :edit
    end
  end

  def destroy
    menu_item = MenuItem.find( params[:id] )
    menu_item.destroy
    redirect_to menu_items_path
  end
  
  def sort
    params[:menu_items].each_with_index do |item_id, index|
      menu_item = MenuItem.find(item_id)
      menu_item.update(:position => index + 1)
    end
    
    head :ok
  end

  private

    def menu_item_params
      params.require(:menu_item).permit(:node_id, :path, :position, :type, :type_id)
    end
end
