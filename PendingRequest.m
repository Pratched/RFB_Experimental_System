classdef PendingRequest
    %PENDINGREQUEST Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Time
        CallbackFcn
    end
    
    methods
        function obj = PendingRequest(time, cb)
            obj.Time = time;
            obj.CallbackFcn = cb;
        end
        
        function et = elapsedTime(obj)
            et = etime(datevec(now), datevec(obj.Time));
        end
    end
end

