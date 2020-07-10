class AlarmTestSerializer < ActiveModel::Serializer
  attributes :id, :alarm_type, :alarm_no, :axis_no, :time, :message, :alarm_status,:created_at,:updated_at,:created_at_test,:updated_at_test,:ex_time
  has_one :machine

def created_at_test
  object.created_at.localtime.strftime("%I:%M:%S %p")
end

def updated_at_test
   #object.updated_at.localtime.strftime("%d-%m-%Y %I:%M:%S %p")
   object.updated_at.localtime.strftime("%I:%M:%S %p")
end
def time
	if object.time == nil
    object.time = "00:00:00"
  else
   object.time
  end
end

def updated_at
   object.updated_at.localtime
   #.strftime("%d-%m-%Y %I:%M %p")
end

def created_at
   object.created_at.localtime
end

def category
  if object.category == nil
    return "Not Entered"
   else
     return object.category
   end
end

def automatic_alarm

end

def ex_time
       if object.time == nil
    object.time = "00:00:00"
  else
     object.time.strftime("%I:%M:%S %p")
  end
  
end

end
