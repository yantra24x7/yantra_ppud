
 require 'net/http'
 require 'uri'
 require 'oj'
 require 'rest-client'

class MachineMonthlyLog < ApplicationRecord
  belongs_to :machine, -> { with_deleted }
   serialize :x_axis, Array
  serialize :y_axis, Array

  def self.delete_data
    MachineMonthlyLog.where("created_at <?",Date.today.beginning_of_month).delete_all
  end

  def self.data_tranfor
     beginning_of_month = Date.today.beginning_of_month
     beginning_of_pre_month = beginning_of_month.months_ago(1)
     previous_month = MachineLog.where(created_at: beginning_of_pre_month..beginning_of_month)
      previous_month.each do | p |
     	PreMonthlyLog.create(parts_count:p.parts_count,machine_status:p.machine_status,job_id:p.job_id,total_run_time:p.total_run_time,total_cutting_time:p.total_cutting_time,run_time:p.run_time,feed_rate:p.feed_rate,cutting_speed:p.cutting_speed,axis_load:p.axis_load,axis_name:p.axis_name,spindle_speed:p.spindle_speed,spindle_load:p.spindle_load,total_run_second:p.total_run_second,programe_number:p.programe_number,run_second:p.run_second,machine_id:p.machine_id)
      end
  end


  # def self.hour_wise_data(params)
  #   mac = Machine.find(params[:machine_id])
  #   tenant = mac.tenant
  #   date = Date.today.strftime("%Y-%m-%d")
  #   shift = Shifttransaction.current_shift(tenant.id)
  #   if CncHourReport.where(machine_id: mac.id date: date, shift_no: shift.shift_no).present?
  #     cnc_reports = CncHourReport.where(machine_id: mac.id date: date, shift_no: shift.shift_no)
      
  #   else
      
  #   end
  # end


      def self.latest_machine_status(params)
   tenant=Tenant.find(params[:tenant_id])
  shift = Shifttransaction.current_shift(tenant.id)
  t_name =  tenant.tenant_name
  if shift != nil
    date = Date.today.to_s
    if shift != []
    case
      when shift.day == 1 && shift.end_day == 1
        start_time = (date+" "+shift.shift_start_time).to_time
        end_time = (date+" "+shift.shift_end_time).to_time
      when shift.day == 1 && shift.end_day == 2
        if Time.now.strftime("%p") == "AM"
          start_time = (date+" "+shift.shift_start_time).to_time-1.day
          end_time = (date+" "+shift.shift_end_time).to_time
        else
          start_time = (date+" "+shift.shift_start_time).to_time
          end_time = (date+" "+shift.shift_end_time).to_time+1.day
        end
      else
       start_time = (date+" "+shift.shift_start_time).to_time
        end_time = (date+" "+shift.shift_end_time).to_time
      end

      tenant.machines.order(:controller_type).map do |mac|
     # machine_log = mac.machine_daily_logs.where("created_at >=? AND created_at <?",start_time,end_time).order(:id)
      machine_log = mac.external_machine_daily_logs.where("created_at >=? AND created_at <?",start_time,end_time).order(:id)
     
      data = {
        :tenant_name=>t_name,
        :unit => mac.unit,
        :mac_name => mac.machine_name,
        :machine_id=>mac.id,
        :machine_status=>machine_log.last.present? ? (Time.now - machine_log.last.created_at) > 600 ? nil : machine_log.last.machine_status : nil,
        :shift_no=>shift.shift_no,
        :start_time=>start_time,
        }
      end
    else
      data = { message:"No shift Currently Avaliable" }
    end
  end
end

    
def self.single_machine_live_status12(params)

  machine = Machine.find(params[:machine_id])
  tenant = machine.tenant
  shift = Shifttransaction.current_shift(tenant.id)
  #  shift = Shifttransaction.find(23)
  date = Date.today.to_s
  if shift != []
  case
    when shift.day == 1 && shift.end_day == 1
      start_time = (date+" "+shift.shift_start_time).to_time
      end_time = (date+" "+shift.shift_end_time).to_time
    when shift.day == 1 && shift.end_day == 2
       if Time.now.strftime("%p") == "AM"
        start_time = (date+" "+shift.shift_start_time).to_time-1.day
        end_time = (date+" "+shift.shift_end_time).to_time
      else
        start_time = (date+" "+shift.shift_start_time).to_time
        end_time = (date+" "+shift.shift_end_time).to_time+1.day
      end
    else
      start_time = (date+" "+shift.shift_start_time).to_time
      end_time = (date+" "+shift.shift_end_time).to_time
    end

    duration = end_time.to_i - start_time.to_i
    dur = Time.now.to_i - start_time.to_i
    machine_log = machine.machine_daily_logs.where("created_at >=? AND created_at <?",start_time,end_time).order(:id)
    if machine_log.present?

      run_time = Machine.calculate_total_run_time (machine_log)
      utilization = (run_time*100)/duration
      stop_time = Machine.stop_time(machine_log)
      idle_time = Machine.ideal_time(machine_log)
   

       axis_return = []
       tem_return = []
       puls_code = []


      if machine_log.where(machine_status: 3).present?
        data = machine_log.where(machine_status: 3).pluck(:programe_number, :parts_count).uniq
        if data.count == 1
          cycle_time = 0
          parts = 0
          cutting_time = 0
          spindle_load = machine_log.last.spindle_load
        else
          cycle_time = machine_log.where(machine_status: 3, parts_count: data[-2][1]).last.run_time.to_i * 60 + machine_log.where(machine_status: 3, parts_count: data[-2][1]).last.run_second.to_i/1000
          parts = data.count
          cutting_time = (machine_log.where(parts_count: data[-2][1]).last.total_cutting_time.to_i * 60 + machine_log.where(parts_count: data[-2][1]).last.total_cutting_second.to_i/1000) - (machine_log.where(parts_count: data[-2][1]).first.total_cutting_time.to_i * 60 + machine_log.where(parts_count: data[-2][1]).first.total_cutting_second.to_i/1000)
          spindle_load = machine_log.last.spindle_load
        end
        job_wise_parts = data.group_by{|x|x[0]}.map{|k,v| [k,v.size]}.to_h
        total_run_time = machine.machine_daily_logs.where(machine_status: 3).last.total_run_time * 100 + machine.machine_daily_logs.where(machine_status: 3).last.total_run_second/1000
        feed_rate = machine_log.pluck(:feed_rate).reject{|i| i == "" || i.nil? || i > 5000 || i == 0 }.last
        spindle_speed = machine_log.pluck(:cutting_speed).reject{|i| i == "" || i.nil? || i == 0 }.last
      else
        cycle_time = 0
        parts = 0
        prog_wise_parts = 0
        total_run_time = 0
        cutting_time = 0
        spindle_load = machine_log.last.spindle_load
        feed_rate = machine_log.pluck(:feed_rate).reject{|i| i == "" || i.nil? || i > 5000 || i == 0 }.last
        spindle_speed = machine_log.pluck(:cutting_speed).reject{|i| i == "" || i.nil? || i == 0 }.last
        job_wise_parts = 0
      end

      data_val = MachineSettingList.where(machine_setting_id: MachineSetting.find_by(machine_id: machine.id).id,is_active: true).pluck(:setting_name)        

       ##   axis_return = []
      machine_log.last.x_axis.first.each_with_index do |key, index|
        if data_val.include?(key[0].to_s)
          axis_return << key
        end
      end
     @val = axis_return.to_h

   ##     tem_return = []

      machine_log.last.y_axis.first.each_with_index do |key, index|

        if data_val.include?(key[0].to_s)
          tem_return << key
        end
      end
      @val2 = tem_return.to_h
      sp_temp = machine_log.last.z_axis

      
 ##     puls_code = []
       machine_log.last.cycle_time_minutes.first.each_with_index do |key, index|
        if data_val.include?(key[0].to_s)
          puls_code << key
        end
      end
     @val3 = puls_code.to_h



      time_diff =  dur - (run_time.to_i+stop_time.to_i+idle_time.to_i)

      if stop_time.to_i > run_time.to_i && stop_time.to_i > idle_time.to_i
        stop = stop_time.to_i + time_diff.to_i
      else
        stop = stop_time.to_i
      end

      if idle_time.to_i >= run_time.to_i && idle_time.to_i >= stop_time.to_i
        idle = idle_time.to_i + time_diff.to_i
      else
        idle = idle_time.to_i
      end


        if run_time.to_i > idle_time.to_i && run_time.to_i > stop_time.to_i
        run = run_time.to_i + time_diff.to_i
      else
        run = run_time.to_i
      end
    end

    if machine.alarm_histories.present?
     alarm = machine.alarm_histories.last.message
    else
     alarm = 'No Alarms '
    end

      data = {
      :start_time => start_time,
      :shift_no => shift.shift_no,
      :shift_time => shift.shift_start_time+ ' - ' +shift.shift_end_time,
      :machine_name => machine.machine_name,
      :utilization => utilization != nil ? utilization : 0,
      :run_time => run != nil ? Time.at(run).utc.strftime("%H:%M:%S") : "00:00:00",
      :idle_time => idle != nil ?  idle > 0 ? Time.at(idle).utc.strftime("%H:%M:%S") : "00:00:00" : "00:00:00",
      :stop_time => stop != nil ? stop > 0 ? Time.at(stop).utc.strftime("%H:%M:%S") : "00:00:00" : "00:00:00",
  
      :cycle_time => cycle_time.present? ? Time.at(cycle_time).utc.strftime("%H:%M:%S") : "00:00:00",
      :cutting_time => cutting_time.present? ? Time.at(cutting_time).utc.strftime("%H:%M:%S") : "00:00:00",

      :machine_status => machine_log.last.present? ? (Time.now - machine_log.last.created_at) > 600 ? nil : machine_log.last.machine_status : nil,
      :machine_disply => machine_log.last.present? ? machine_log.last.parts_count.to_i : 0,
      :parts_count => parts.present? ? parts : 0,
      :job_name => machine.machine_daily_logs.where.not(:job_id=>"",:programe_number=>nil).order(:id).last.present? ? ""+machine.machine_daily_logs.where.not(:job_id=>"",:programe_number=>nil).order(:id).last.programe_number+"-"+machine.machine_daily_logs.where.not(:job_id=>"",:programe_number=>nil).order(:id).last.job_id : nil ,
      :total_run_time => total_run_time != nil ? total_run_time > 0 ? Time.at(total_run_time).utc.strftime("%H:%M:%S") : "00:00:00" : "00:00:00",
      :alarm => alarm,
      :job_wise_parts => job_wise_parts.present? ? job_wise_parts : 0,
      :feed_rate => feed_rate.present? ? feed_rate : 0,
      :spindle_load => spindle_load.present? ?  spindle_load : 0,
      :spindle_speed => spindle_speed.present? ? spindle_speed : 0,
      :sp_temp => sp_temp,
     # :axis_load => @val,
      :axis_load => axis_return.present? ? axis_return.to_h : [],
     # :axis_tem => @val2,
      :axis_tem => tem_return.present? ? tem_return.to_h : [],
      :puls_code => puls_code.present? ? puls_code.to_h : [],
      :axis_tem_count => @val2.count
     # :time => Time.now.localtime
    }

    else
      data = { message:"No shift Currently Avaliable" }
    end
end



def self.single_machine_live_status212(params)

  machine = Machine.find(params[:machine_id])
  tenant = machine.tenant
  shift = Shifttransaction.current_shift(tenant.id)
  #  shift = Shifttransaction.find(23)
  date = Date.today.to_s
  if shift != []
  case
    when shift.day == 1 && shift.end_day == 1
      start_time = (date+" "+shift.shift_start_time).to_time
      end_time = (date+" "+shift.shift_end_time).to_time
    when shift.day == 1 && shift.end_day == 2
       if Time.now.strftime("%p") == "AM"
        start_time = (date+" "+shift.shift_start_time).to_time-1.day
        end_time = (date+" "+shift.shift_end_time).to_time
      else
        start_time = (date+" "+shift.shift_start_time).to_time
        end_time = (date+" "+shift.shift_end_time).to_time+1.day
      end
    else
      start_time = (date+" "+shift.shift_start_time).to_time
      end_time = (date+" "+shift.shift_end_time).to_time
    end

    duration = end_time.to_i - start_time.to_i
    dur = Time.now.to_i - start_time.to_i
    machine_log = machine.machine_daily_logs.where("created_at >=? AND created_at <?",start_time,end_time).order(:id)
    if machine_log.present?

      run_time = Machine.calculate_total_run_time (machine_log)
      utilization = (run_time*100)/duration
      stop_time = Machine.stop_time(machine_log)
      idle_time = Machine.ideal_time(machine_log)


       axis_return = []
       tem_return = []
       puls_code = []

           if machine_log.where(machine_status: 3).present?
        data = machine_log.where(machine_status: 3).pluck(:programe_number, :parts_count).uniq
        if data.count == 1
          cycle_time = 0
          parts = 0
          cutting_time = 0
          spindle_load = machine_log.last.spindle_load
        else
          cycle_time = machine_log.where(machine_status: 3, parts_count: data[-2][1]).last.run_time.to_i * 60 + machine_log.where(machine_status: 3, parts_count: data[-2][1]).last.run_second.to_i/1000
          parts = data.count
          cutting_time = (machine_log.where(parts_count: data[-2][1]).last.total_cutting_time.to_i * 60 + machine_log.where(parts_count: data[-2][1]).last.total_cutting_second.to_i/1000) - (machine_log.where(parts_count: data[-2][1]).first.total_cutting_time.to_i * 60 + machine_log.where(parts_count: data[-2][1]).first.total_cutting_second.to_i/1000)
          spindle_load = machine_log.last.spindle_load
        end
        job_wise_parts = data.group_by{|x|x[0]}.map{|k,v| [k,v.size]}.to_h
        total_run_time = machine.machine_daily_logs.where(machine_status: 3).last.total_run_time * 100 + machine.machine_daily_logs.where(machine_status: 3).last.total_run_second/1000
        feed_rate = machine_log.pluck(:feed_rate).reject{|i| i == "" || i.nil? || i > 5000 || i == 0 }.last
        spindle_speed = machine_log.pluck(:cutting_speed).reject{|i| i == "" || i.nil? || i == 0 }.last
      else
        cycle_time = 0
        parts = 0
        prog_wise_parts = 0
        total_run_time = 0
        cutting_time = 0
        spindle_load = machine_log.last.spindle_load
        feed_rate = machine_log.pluck(:feed_rate).reject{|i| i == "" || i.nil? || i > 5000 || i == 0 }.last
        spindle_speed = machine_log.pluck(:cutting_speed).reject{|i| i == "" || i.nil? || i == 0 }.last
        job_wise_parts = 0
      end

      data_val = MachineSettingList.where(machine_setting_id: MachineSetting.find_by(machine_id: machine.id).id,is_active: true).pluck(:setting_name)
       if machine_log.where(machine_status: 3).present? 
        machine_log.last.x_axis.first.each_with_index do |key, index|
        if data_val.include?(key[0].to_s)
          axis_return << key
        end
      end
     @val = axis_return.to_h

   ##     tem_return = []

      machine_log.last.y_axis.first.each_with_index do |key, index|

        if data_val.include?(key[0].to_s)
          tem_return << key
        end
      end
      @val2 = tem_return.to_h
      sp_temp = machine_log.last.z_axis


 ##     puls_code = []
       machine_log.last.cycle_time_minutes.first.each_with_index do |key, index|
        if data_val.include?(key[0].to_s)
          puls_code << key
        end
      end
     @val3 = puls_code.to_h
     else
      
       machine_log.last.x_axis.first.each_with_index do |key, index|
        if data_val.include?(key[0].to_s)
          axis_return << [key[0], 0]
          #byebug
        end
      end
     @val = axis_return.to_h

   ##     tem_return = []

      machine_log.last.y_axis.first.each_with_index do |key, index|

        if data_val.include?(key[0].to_s)
          tem_return << [key[0], 0]
        end
      end
      @val2 = tem_return.to_h
      sp_temp = 0


 ##     puls_code = []
       machine_log.last.cycle_time_minutes.first.each_with_index do |key, index|
        if data_val.include?(key[0].to_s)
          puls_code << [key[0], 0]
        end
      end
     @val3 = puls_code.to_h


     end



      time_diff =  dur - (run_time.to_i+stop_time.to_i+idle_time.to_i)

         if stop_time.to_i > run_time.to_i && stop_time.to_i > idle_time.to_i
        stop = stop_time.to_i + time_diff.to_i
      else
        stop = stop_time.to_i
      end

      if idle_time.to_i >= run_time.to_i && idle_time.to_i >= stop_time.to_i
        idle = idle_time.to_i + time_diff.to_i
      else
        idle = idle_time.to_i
      end


        if run_time.to_i > idle_time.to_i && run_time.to_i > stop_time.to_i
        run = run_time.to_i + time_diff.to_i
      else
        run = run_time.to_i
      end
    end

    if machine.alarm_histories.present?
     alarm = machine.alarm_histories.last.message
    else
     alarm = 'No Alarms '
    end

      data = {
      :start_time => start_time,
      :shift_no => shift.shift_no,
      :shift_time => shift.shift_start_time+ ' - ' +shift.shift_end_time,
      :machine_name => machine.machine_name,
      :utilization => utilization != nil ? utilization : 0,
      :run_time => run != nil ? Time.at(run).utc.strftime("%H:%M:%S") : "00:00:00",
      :idle_time => idle != nil ?  idle > 0 ? Time.at(idle).utc.strftime("%H:%M:%S") : "00:00:00" : "00:00:00",
      :stop_time => stop != nil ? stop > 0 ? Time.at(stop).utc.strftime("%H:%M:%S") : "00:00:00" : "00:00:00",

          :cycle_time => cycle_time.present? ? Time.at(cycle_time).utc.strftime("%H:%M:%S") : "00:00:00",
      :cutting_time => cutting_time.present? ? Time.at(cutting_time).utc.strftime("%H:%M:%S") : "00:00:00",

      :machine_status => machine_log.last.present? ? (Time.now - machine_log.last.created_at) > 600 ? nil : machine_log.last.machine_status : nil,
      :machine_disply => machine_log.last.present? ? machine_log.last.parts_count.to_i : 0,
      :parts_count => parts.present? ? parts : 0,
      :job_name => machine.machine_daily_logs.where.not(:job_id=>"",:programe_number=>nil).order(:id).last.present? ? ""+machine.machine_daily_logs.where.not(:job_id=>"",:programe_number=>nil).order(:id).last.programe_number+"-"+machine.machine_daily_logs.where.not(:job_id=>"",:programe_number=>nil).order(:id).last.job_id : nil ,
      :total_run_time => total_run_time != nil ? total_run_time > 0 ? Time.at(total_run_time).utc.strftime("%H:%M:%S") : "00:00:00" : "00:00:00",
      :alarm => alarm,
      :job_wise_parts => job_wise_parts.present? ? job_wise_parts : 0,
      :feed_rate => feed_rate.present? ? feed_rate : 0,
      :spindle_load => spindle_load.present? ?  spindle_load : 0,
      :spindle_speed => spindle_speed.present? ? spindle_speed : 0,
      :sp_temp => sp_temp,
     # :axis_load => @val,
      :axis_load => axis_return.present? ? axis_return.to_h : [],
     # :axis_tem => @val2,
      :axis_tem => tem_return.present? ? tem_return.to_h : [],
      :puls_code => puls_code.present? ? puls_code.to_h : [],
      :axis_tem_count => @val2.count
     # :time => Time.now.localtime
    }

    else
      data = { message:"No shift Currently Avaliable" }
    end
end





  #------------------------ Final  -------------------------#
  
  



   def self.single_machine_live_status23457(params)
  machine = Machine.find(params[:machine_id])
  tenant = machine.tenant
  shift = Shifttransaction.current_shift(tenant.id)
  #  shift = Shifttransaction.find(23)
  date = Date.today.to_s
  if shift != []
  case
    when shift.day == 1 && shift.end_day == 1
      start_time = (date+" "+shift.shift_start_time).to_time
      end_time = (date+" "+shift.shift_end_time).to_time
    when shift.day == 1 && shift.end_day == 2
       if Time.now.strftime("%p") == "AM"
        start_time = (date+" "+shift.shift_start_time).to_time-1.day
        end_time = (date+" "+shift.shift_end_time).to_time
      else
        start_time = (date+" "+shift.shift_start_time).to_time
        end_time = (date+" "+shift.shift_end_time).to_time+1.day
      end
    else
      start_time = (date+" "+shift.shift_start_time).to_time
      end_time = (date+" "+shift.shift_end_time).to_time
    end

    duration = end_time.to_i - start_time.to_i
    dur = Time.now.to_i - start_time.to_i
    machine_log = machine.machine_daily_logs.where("created_at >=? AND created_at <?",start_time,end_time).order(:id)
    if machine_log.present?

     unless machine.controller_type == 4
       run_time = Machine.calculate_total_run_time (machine_log)
     else
      run_time = Machine.run_time(machine_log)
     end
     
      utilization = (run_time*100)/duration
      stop_time = Machine.stop_time(machine_log)
      idle_time = Machine.ideal_time(machine_log)


       axis_return = []
       tem_return = []
       puls_code = []


      if machine_log.where(machine_status: 3).present?
        if machine.controller_type == 4
          data = machine_log.where.not(machine_status: 100).split{|o| o.machine_status == 5}.reject{|i| i.empty? }
        else
          data = machine_log.where(machine_status: 3).pluck(:programe_number, :parts_count).uniq
        end
        
        if data.count == 1
          cycle_time = 0
          parts = 0
          cutting_time = 0
          if machine.controller_type == 4
            spindle_load = 0
          else
            spindle_load = machine_log.last.spindle_load
          end
        else
          parts = data.count
          if machine.controller_type == 4
            cycle_time = data[-2].last.created_at.to_i - data[-2].first.created_at.to_i
            cutting_time = cycle_time
            spindle_load = 0
          else
            cycle_time = machine_log.where(machine_status: 3, parts_count: data[-2][1]).last.run_time.to_i * 60 + machine_log.where(machine_status: 3, parts_count: data[-2][1]).last.run_second.to_i/1000          
            cutting_time = (machine_log.where(parts_count: data[-2][1]).last.total_cutting_time.to_i * 60 + machine_log.where(parts_count: data[-2][1]).last.total_cutting_second.to_i/1000) - (machine_log.where(parts_count: data[-2][1]).first.total_cutting_time.to_i * 60 + machine_log.where(parts_count: data[-2][1]).first.total_cutting_second.to_i/1000)
            spindle_load = machine_log.last.spindle_load
          end
        end
        
        if machine.controller_type == 4 || machine.controller_type == 2
          job_wise_parts = 0
          total_run_time = 0
          feed_rate = 0
          spindle_speed = 0
        else
          job_wise_parts = data.group_by{|x|x[0]}.map{|k,v| [k,v.size]}.to_h
          total_run_time = machine.machine_daily_logs.where(machine_status: 3).last.total_run_time * 100 + machine.machine_daily_logs.where(machine_status: 3).last.total_run_second/1000
          feed_rate = machine_log.pluck(:feed_rate).reject{|i| i == "" || i.nil? || i > 5000 }.last
          spindle_speed = machine_log.pluck(:cutting_speed).reject{|i| i == "" || i.nil? }.last
        end
      else
        cycle_time = 0
        parts = 0
        prog_wise_parts = 0
        total_run_time = 0
        cutting_time = 0
        job_wise_parts = 0
        
        if machine.controller_type == 4
          spindle_load = 0
          feed_rate = 0
          spindle_speed = 0
        else
          spindle_load = machine_log.last.spindle_load
          feed_rate = machine_log.pluck(:feed_rate).reject{|i| i == "" || i.nil? || i > 5000 }.last
          spindle_speed = machine_log.pluck(:cutting_speed).reject{|i| i == "" || i.nil? }.last
        end
      end
#byebug
      data_val = MachineSettingList.where(machine_setting_id: MachineSetting.find_by(machine_id: machine.id).id,is_active: true).pluck(:setting_name)
            ##   axis_return = []
            #byebug
  unless machine.controller_type == 4
    if machine_log.where(machine_status: 3).present?      
      machine_log.last.x_axis.first.each_with_index do |key, index|
        if data_val.include?(key[0].to_s)
          axis_return << key
        end
      end
     @val = axis_return.to_h

   ##     tem_return = []

      machine_log.last.y_axis.first.each_with_index do |key, index|

        if data_val.include?(key[0].to_s)
          tem_return << key
        end
      end
      @val2 = tem_return.to_h
      sp_temp = machine_log.last.z_axis


 ##     puls_code = []
       machine_log.last.cycle_time_minutes.first.each_with_index do |key, index|
        if data_val.include?(key[0].to_s)
          puls_code << key
        end
      end
     @val3 = puls_code.to_h
   
    else

      machine_log.last.x_axis.first.each_with_index do |key, index|
        if data_val.include?(key[0].to_s)
          axis_return << [key[0], 0]
          #byebug
        end
      end
     @val = axis_return.to_h

   ##     tem_return = []

      machine_log.last.y_axis.first.each_with_index do |key, index|

        if data_val.include?(key[0].to_s)
          tem_return << [key[0], 0]
        end
      end
      @val2 = tem_return.to_h
      sp_temp = 0


 ##     puls_code = []
       machine_log.last.cycle_time_minutes.first.each_with_index do |key, index|
        if data_val.include?(key[0].to_s)
          puls_code << [key[0], 0]
        end
      end
     @val3 = puls_code.to_h

    end
    else

   #  machine_log.last.x_axis.first.each_with_index do |key, index|
    #    if data_val.include?(key[0].to_s)
   #       axis_return << [key[0], 0]
          #byebug
  #      end
  #    end
  #   @val = axis_return.to_h

   ##     tem_return = []

   #   machine_log.last.y_axis.first.each_with_index do |key, index|

    #    if data_val.include?(key[0].to_s)
    #      tem_return << [key[0], 0]
    #    end
    #  end
    #  @val2 = tem_return.to_h
    #  sp_temp = 0


 ##     puls_code = []
    #   machine_log.last.cycle_time_minutes.first.each_with_index do |key, index|
    #    if data_val.include?(key[0].to_s)
    #      puls_code << [key[0], 0]
    #    end
    #  end
    # @val3 = puls_code.to_h

      data_val.each do |ii|
       puls_code << [ii, 0]
       tem_return << [ii, 0]
       axis_return << [ii, 0]
     end

       @val3 = puls_code.to_h
       @val2 = tem_return.to_h
       @val = axis_return.to_h
       sp_temp = 0

    end


      time_diff =  dur - (run_time.to_i+stop_time.to_i+idle_time.to_i)

      if stop_time.to_i > run_time.to_i && stop_time.to_i > idle_time.to_i
        stop = stop_time.to_i + time_diff.to_i
      else
        stop = stop_time.to_i
      end

      if idle_time.to_i >= run_time.to_i && idle_time.to_i >= stop_time.to_i
        idle = idle_time.to_i + time_diff.to_i
      else
        idle = idle_time.to_i
      end


      if run_time.to_i > idle_time.to_i && run_time.to_i > stop_time.to_i
        run = run_time.to_i + time_diff.to_i
      else
        run = run_time.to_i
      end
    end

    if machine.alarm_histories.present?
     alarm = machine.alarm_histories.last.message
    else
     alarm = 'No Alarms '
    end


      data = {
      :start_time => start_time,
      :shift_no => shift.shift_no,
      :shift_time => shift.shift_start_time+ ' - ' +shift.shift_end_time,
      :machine_name => machine.machine_name,
      :utilization => utilization != nil ? utilization : 0,
      :run_time => run != nil ? Time.at(run).utc.strftime("%H:%M:%S") : "00:00:00",
      :idle_time => idle != nil ?  idle > 0 ? Time.at(idle).utc.strftime("%H:%M:%S") : "00:00:00" : "00:00:00",
      :stop_time => stop != nil ? stop > 0 ? Time.at(stop).utc.strftime("%H:%M:%S") : "00:00:00" : "00:00:00",
      :cycle_time => cycle_time.present? ? Time.at(cycle_time).utc.strftime("%H:%M:%S") : "00:00:00",
      :cutting_time => cutting_time.present? ? Time.at(cutting_time).utc.strftime("%H:%M:%S") : "00:00:00",
      :machine_status => machine_log.last.present? ? (Time.now - machine_log.last.created_at) > 600 ? nil : machine_log.last.machine_status : nil,
      :machine_disply => machine_log.last.present? ? machine_log.last.parts_count.to_i : 0,
      :parts_count => parts.present? ? parts : 0,
      :job_name => machine.machine_daily_logs.where.not(:job_id=>"",:programe_number=>nil).order(:id).last.present? ? ""+machine.machine_daily_logs.where.not(:job_id=>"",:programe_number=>nil).order(:id).last.programe_number+"-"+machine.machine_daily_logs.where.not(:job_id=>"",:programe_number=>nil).order(:id).last.job_id : nil ,
      :total_run_time => total_run_time != nil ? total_run_time > 0 ? Time.at(total_run_time).utc.strftime("%H:%M:%S") : "00:00:00" : "00:00:00",
      :alarm => alarm,
      :job_wise_parts => job_wise_parts.present? ? job_wise_parts : 0,
      :feed_rate => feed_rate.present? ? feed_rate : 0,
      :spindle_load => spindle_load.present? ?  spindle_load : 0,
      :spindle_speed => spindle_speed.present? ? spindle_speed : 0,
      :sp_temp => sp_temp.present? ? sp_temp : 0,
     # :axis_load => @val,
      :axis_load => axis_return.present? ? axis_return.to_h : [],
     # :axis_tem => @val2,
      :axis_tem => tem_return.present? ? tem_return.to_h : [],
      :puls_code => puls_code.present? ? puls_code.to_h : [],
      :axis_tem_count => @val2.present? ? @val2.count : 0,# @val2.count,
      :res => 'test'
      
     # :axis_tem_count => @val2.count
     # :time => Time.now.localtime
    }

    else
      data = { message:"No shift Currently Avaliable" }
    end
end

   # ---------------------- end  ----------------------------#



   #  ----------------------final1 --------------------------- #

  def self.single_machine_live_status(params)
  machine = Machine.find(params[:machine_id])
  #machine = Machine.find(8)
  tenant = machine.tenant
  shift = Shifttransaction.current_shift(tenant.id)
  #  shift = Shifttransaction.find(23)
  date = Date.today.to_s
  if shift != []
  case
    when shift.day == 1 && shift.end_day == 1
      start_time = (date+" "+shift.shift_start_time).to_time
      end_time = (date+" "+shift.shift_end_time).to_time
    when shift.day == 1 && shift.end_day == 2
       if Time.now.strftime("%p") == "AM"
        start_time = (date+" "+shift.shift_start_time).to_time-1.day
        end_time = (date+" "+shift.shift_end_time).to_time
      else
        start_time = (date+" "+shift.shift_start_time).to_time
        end_time = (date+" "+shift.shift_end_time).to_time+1.day
      end
    else
      start_time = (date+" "+shift.shift_start_time).to_time
      end_time = (date+" "+shift.shift_end_time).to_time
    end

    duration = end_time.to_i - start_time.to_i
    dur = Time.now.to_i - start_time.to_i
    

  #  machine_log = machine.machine_daily_logs.where("created_at >=? AND created_at <?",start_time,end_time).order(:id)
    
   machine_log = machine.external_machine_daily_logs.where("created_at >=? AND created_at <?",start_time,end_time).order(:id)
   ###@# 
   machine_log11 = machine.external_machine_daily_logs 
   ###@#

    #13.235.38.201/api/v1/cr_datum?machine=6&start_time="2019-09-16 16:00:00"&end_time="2019-09-16 20:00:00"
 #     url = "http://13.235.38.201/api/v1/cr_datum?machine=#{params[:machine_id]}&start_time=start_time&end_time=end_time"
  #    data = RestClient::Request.execute(method: :get, url: url)
     # machine_log = JSON.parse(data)

     if machine_log.present?

      if machine.controller_type == 1 || machine.controller_type == 3
        run_time = Machine.calculate_total_run_time (machine_log)
        machine_display = machine.external_machine_daily_logs.last.parts_count.present? ? machine.external_machine_logs.last.parts_count.to_i: 0
      #  machine_display = machine.machine_logs.last.parts_count.to_i
      else
        run_time = Machine.run_time(machine_log)
        machine_display = machine.external_machine_daily_logs.last.parts_count == 0 ? 0: machine.external_machine_logs.last.parts_count.to_i+1
       # machine_display = machine.machine_logs.last.parts_count.to_i + 1
      end

      utilization = (run_time*100)/duration
      stop_time = Machine.stop_time(machine_log)
      idle_time = Machine.ideal_time(machine_log)

      axis_return = []
       tem_return = []
       puls_code = []


     # if machine_log.where(machine_status: 3).present?
      if machine_log.pluck(:machine_status).include?(3)
       if machine.controller_type == 2
        # data = machine_log.where(machine_status: 3).pluck(:programe_number, :parts_count).uniq
          data = machine_log.select{|a| a.machine_status == 3}.pluck(:programe_number, :parts_count).uniq
        elsif machine.controller_type == 4
          data = machine_log.where.not(machine_status: 100).split{|o| o.machine_status == 5}.reject{|i| i.empty? }
        else
          ###@#
           data = BreakTime.parts_time3(machine_log.to_a, machine_log11.to_a,shift.shift_no,shift.id, date)
          ###@#
          #data = machine_log.select{|a| a.machine_status == 3}.pluck(:programe_number, :parts_count).uniq
        end

        if data.count == 1
          cycle_time = 0
          parts = 0
          cutting_time = 0

          if machine.controller_type == 1
            spindle_load = machine_log.last.spindle_load
          elsif machine.controller_type == 4 || machine.controller_type == 2
            spindle_load = 0
          else
            spindle_load = machine_log.last.spindle_load
          end
        else
          parts = data.count
          if machine.controller_type == 4
            cycle_time = data[-2].last.created_at.to_i - data[-2].first.created_at.to_i
            cutting_time = cycle_time
            spindle_load = 0
          elsif machine.controller_type == 5
            cycle_time = machine_log.where(machine_status: 3, parts_count: data[-2][1]).last.created_at - machine_log.where(machine_status: 3, parts_count: data[-2][1]).first.created_at
            cutting_time = cycle_time
            spindle_load = machine_log.last.spindle_load
          elsif machine.controller_type == 2
           # cycle_time = machine_log.where(machine_status: 3, parts_count: data[-2][1]).last.created_at - machine_log.where(machine_status: 3, parts_count: data[-2][1]).first.created_at
            cycle_time = machine_log.select{|a| a.machine_status == 3 && a.parts_count == data[-2][1].to_i}.last.created_at - machine_log.select{|a| a.machine_status == 3 && a.parts_count == data[-2][1].to_i}.first.created_at
            cutting_time = 0
            spindle_load = 0
           else
            # cycle_time = machine_log.select{|a| a.machine_status == 3 && a.parts_count == data[-2][1].to_i}.last.run_time.to_i * 60 + machine_log.select{|a| a.machine_status == 3 && a.parts_count == data[-2][1].to_i}.last.run_second.to_i/1000
            # cutting_time = (machine_log.select{|a| a.parts_count == data[-2][1].to_i}.last.total_cutting_time.to_i * 60 + machine_log.select{|a| a.parts_count == data[-2][1].to_i}.last.total_cutting_second.to_i/1000) - (machine_log.select{|a| a.parts_count == data[-2][1].to_i}.first.total_cutting_time.to_i * 60 + machine_log.select{|a| a.parts_count == data[-2][1].to_i}.first.total_cutting_second.to_i/1000)
          ###@#
             if data[-2].present?
              cycle_time = data[-2].cycle_time.first[:cycle_time]
              cutting_time = data[-2].cutting_time.to_i
            else
              cycle_time = data[-1].cycle_time.first[:cycle_time]
              cutting_time = data[-1].cutting_time.to_i
            end
           ###@#


            spindle_load = machine_log.last.spindle_load
          end
        end

        if machine.controller_type == 4 || machine.controller_type == 2
      #   job_wise_parts = 0
          job_wise_parts = data.group_by{|x|x[0]}.map{|k,v| [k,v.size]}.to_h
          total_run_time = 0
          feed_rate = 0
          spindle_speed = 0
        else
          if data.count == 1
            job_wise_parts = 0
          else
            ###@#
             job_wise_parts = data.pluck(:program_number, :part).group_by{|x|x[0]}.map{|k,v| [k,v.size]}.to_h
            ###@#
            # job_wise_parts = data.group_by{|x|x[0]}.map{|k,v| [k,v.size]}.to_h
          end
         #job_wise_parts = 0
         # total_run_time = machine.external_machine_daily_logs.where(machine_status: 3).last.total_run_time * 100 + machine.external_machine_daily_logs.where(machine_status: 3).last.total_run_second/1000
          total_run_time = machine_log.select{|a| a.machine_status == 3}.last.total_run_time * 100 + machine_log.select{|a| a.machine_status == 3}.last.total_run_second/1000
          feed_rate = machine_log.pluck(:feed_rate).reject{|i| i == "" || i.nil? || i > 5000  }.last
          spindle_speed = machine_log.pluck(:cutting_speed).reject{|i| i == "" || i.nil?  }.last
        end

      else
        cycle_time = 0
        parts = 0
        prog_wise_parts = 0
        total_run_time = 0
        cutting_time = 0
        job_wise_parts = 0

        if machine.controller_type == 4
          spindle_load = 0
          feed_rate = 0
          spindle_speed = 0
        else
          spindle_load = machine_log.last.spindle_load
          feed_rate = machine_log.pluck(:feed_rate).reject{|i| i == "" || i.nil? || i > 5000 || i == 0 }.last
          spindle_speed = machine_log.pluck(:cutting_speed).reject{|i| i == "" || i.nil? || i == 0 }.last
        end
      end
      data_val = MachineSettingList.where(machine_setting_id: MachineSetting.find_by(machine_id: machine.id).id,is_active: true).pluck(:setting_name)
            ##   axis_return = []
            #byebug
  unless machine.controller_type == 4 || machine.controller_type == 2
   # if machine_log.where(machine_status: 3).present?
     if machine_log.pluck(:machine_status).include?(3)
      machine_log.last.x_axis.first.each_with_index do |key, index|
        if data_val.include?(key[0].to_s)
          axis_return << key
        end
      end
     @val = axis_return.to_h

   ##     tem_return = []

      machine_log.last.y_axis.first.each_with_index do |key, index|

        if data_val.include?(key[0].to_s)
          tem_return << key
        end
      end
      @val2 = tem_return.to_h
      sp_temp = machine_log.last.z_axis


 ##     puls_code = []
       machine_log.last.cycle_time_minutes.first.each_with_index do |key, index|
        if data_val.include?(key[0].to_s)
          puls_code << key
        end
      end
     @val3 = puls_code.to_h

    else

      machine_log.last.x_axis.first.each_with_index do |key, index|
        if data_val.include?(key[0].to_s)
          axis_return << [key[0], 0]
          #byebug
        end
      end
     @val = axis_return.to_h
       machine_log.last.y_axis.first.each_with_index do |key, index|

        if data_val.include?(key[0].to_s)
          tem_return << [key[0], 0]
        end
      end
      @val2 = tem_return.to_h
      sp_temp = 0


 ##     puls_code = []
       machine_log.last.cycle_time_minutes.first.each_with_index do |key, index|
        if data_val.include?(key[0].to_s)
          puls_code << [key[0], 0]
        end
      end
     @val3 = puls_code.to_h

    end
    else
       data_val.each do |ii|
       puls_code << [ii, "NA"]
       tem_return << [ii, "NA"]
       axis_return << [ii, 0]
     end

       @val3 = puls_code.to_h
       @val2 = tem_return.to_h
       @val = axis_return.to_h
       sp_temp = 0

    end
      time_diff =  dur - (run_time.to_i+stop_time.to_i+idle_time.to_i)

      if stop_time.to_i > run_time.to_i && stop_time.to_i > idle_time.to_i
        stop = stop_time.to_i + time_diff.to_i
      else
        stop = stop_time.to_i
      end

      if idle_time.to_i >= run_time.to_i && idle_time.to_i >= stop_time.to_i
        idle = idle_time.to_i + time_diff.to_i
      else
        idle = idle_time.to_i
      end


      if run_time.to_i > idle_time.to_i && run_time.to_i > stop_time.to_i
        run = run_time.to_i + time_diff.to_i
      else
        run = run_time.to_i
      end
    end
    
  # if machine_log.where(machine_status: 3).present?
   if machine_log.pluck(:machine_status).include?(3)
    if machine.alarms.present?
     alarm = machine.alarms.last.alarm_message
    else
     alarm = 'No Alarms '
    end
   end

    if shift.operator_allocations.where(machine_id:machine.id).last.nil?
			  operator_id = nil
			else
			  if shift.operator_allocations.where(machine_id:machine.id).present?
				shift.operator_allocations.where(machine_id:machine.id).each do |ro| 
				  aa = ro.from_date
				  bb = ro.to_date
				  cc = date
				  if cc.to_date.between?(aa.to_date,bb.to_date)  
					dd = ro#cc.to_date.between?(aa.to_date,bb.to_date)
					if dd.operator_mapping_allocations.where(:date=>date.to_date).last.operator.present?
					  operator_id = dd.operator_mapping_allocations.where(:date=>date.to_date).last.operator.operator_name
					else
					  operator_id = nil
					end              
				  end
				end
			  else
				operator_id = nil
			  end
			end

      
       data = {
      :last_update=>machine.external_machine_logs.last.present? ? machine.external_machine_logs.order(:id).last.created_at.in_time_zone("Chennai") : 0,
      :shift_no => shift.shift_no,
      :shift_time => shift.shift_start_time+ ' - ' +shift.shift_end_time,
      :machine_name => machine.machine_name,
      :machine_id => machine.id,
      :utilization => utilization != nil ? utilization : 0,
      :run_time => run != nil ? Time.at(run).utc.strftime("%H:%M:%S") : "00:00:00",
      :idle_time => idle != nil ?  idle > 0 ? Time.at(idle).utc.strftime("%H:%M:%S") : "00:00:00" : "00:00:00",
      :stop_time => stop != nil ? stop > 0 ? Time.at(stop).utc.strftime("%H:%M:%S") : "00:00:00" : "00:00:00",
      :cycle_time => cycle_time.present? ? Time.at(cycle_time).utc.strftime("%H:%M:%S") : "00:00:00",
      :cutting_time => cutting_time.present? ? Time.at(cutting_time).utc.strftime("%H:%M:%S") : "00:00:00",
      :machine_status => machine_log.last.present? ? (Time.now - machine_log.last.created_at) > 600 ? nil : machine_log.last.machine_status : nil,
      :machine_disply => machine_display.present? ? machine_display : 0,
      :parts_count => parts.present? ? parts : 0,
     # :job_name => machine.external_machine_daily_logs.where.not(:job_id=>"",:programe_number=>nil).order(:id).last.present? ? ""+machine.external_machine_daily_logs.where.not(:job_id=>"",:programe_number=>nil).order(:id).last.programe_number+"-"+machine.external_machine_daily_logs.where.not(:job_id=>"",:programe_number=>nil).order(:id).last.job_id : nil ,
      :job_name => machine_log.select{|a| a.job_id != "" && a.programe_number != nil}.last.present? ? ""+machine_log.select{|a| a.job_id != "" && a.programe_number != nil}.last.programe_number+"-"+machine_log.select{|a| a.job_id != "" && a.programe_number != nil}.last.job_id : nil,
      :total_run_time => total_run_time != nil ? total_run_time > 0 ? Time.at(total_run_time).utc.strftime("%H:%M:%S") : "00:00:00" : "00:00:00",
      :alarm => alarm,
      :job_wise_parts => job_wise_parts.present? ? job_wise_parts : 0,
      :feed_rate => feed_rate.present? ? feed_rate : 0,
      :spindle_load => spindle_load.present? ?  spindle_load : 0,
      :spindle_speed => spindle_speed.present? ? spindle_speed : 0,
      :sp_temp => sp_temp,
     # :axis_load => @val,
      :axis_load => axis_return.present? ? axis_return.to_h : [],
     # :axis_tem => @val2,
      :axis_tem => tem_return.present? ? tem_return.to_h : [],
      :puls_code => puls_code.present? ? puls_code.to_h : [],
      :axis_tem_count => @val2.present? ? @val2.count : 0,
      :start_time=>start_time,
      :operator_allocation=>operator_id.present? ? operator_id : "Name not Entered"
     # :axis_tem_count => @val2.count
     # :time => Time.now.localtime
    }

    else
      data = { message:"No shift Currently Avaliable" }
    end
end









   #  ---------------------- end --------------------------------#





end
