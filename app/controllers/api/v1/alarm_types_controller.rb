module Api
  module V1
  class AlarmTypesController < ApplicationController
  before_action :set_alarm_type, only: [:show, :update, :destroy]
  skip_before_action :authenticate_request, only: %i[ss]
  # GET /alarm_types
  def ss
   data = Approval.record
   render json: data
  end
  def index
   alarm= AlarmType.all

    #render json: @alarm_types
   #  machine_name=ActiveSupport::JSON.decode(Machine.all.to_json(:only => [:id,:machine_name]))
   
   set_status = SetAlarmSetting.includes(:machine).where(machines: {tenant_id:params[:tenant_id]})
    data ={"alarm_type"=>alarm,"status"=>["idel","stop"]}    
    render json: data
  end

  # GET /alarm_types/1
  def show
    render json: @alarm_type
  end

  # POST /alarm_types
  def create
    @alarm_type = AlarmType.new(alarm_type_params)

    if @alarm_type.save
      render json: @alarm_type, status: :created, location: @alarm_type
    else
      render json: @alarm_type.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /alarm_types/1
  def update
    if @alarm_type.update(alarm_type_params)
      render json: @alarm_type
    else
      render json: @alarm_type.errors, status: :unprocessable_entity
    end
  end

  # DELETE /alarm_types/1
  def destroy
    @alarm_type.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_alarm_type
      @alarm_type = AlarmType.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def alarm_type_params
      params.require(:alarm_type).permit(:alarm_name)
    end
end
end
end
