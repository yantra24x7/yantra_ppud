module Api
  module V1
class PagesController < ApplicationController
  before_action :set_page, only: [:show, :update, :destroy]
  skip_before_action :authenticate_request, only: %i[mobile_version]
  # GET /pages
  def mobile_version
    @value = Page.last.icon.to_i
    render json: {version: 4.2}
  end

   def mobile_version_ios
    @value = Page.last.icon.to_i
    render json: {version: 1.6}
  end

  # GET /pages
  def index
    @pages = Page.all
    render json: @pages
  end

  # GET /pages/1
  def show
    render json: @page
  end

  # POST /pages
  def create
    @page = Page.new(page_params)

    if @page.save
      render json: @page, status: :created#, location: @page
    else
      render json: @page.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /pages/1
  def update
    if @page.update(page_params)
      render json: @page
    else
      render json: @page.errors, status: :unprocessable_entity
    end
  end

  # DELETE /pages/1
  def destroy
    @page.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_page
      @page = Page.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def page_params
      params.require(:page).permit(:page_name, :icon, :url, :parent_page_id, :usertype_id)
    end
end
end
end
