classdef MeasurementStorage
    %MEASUREMENTSTORAGE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        ValueMap
        OrderedKeys
    end
    
    methods
        function obj = MeasurementStorage(measurementKeys)
            %MEASUREMENTSTORAGE Construct an instance of this class
            %   Detailed explanation goes here
            obj.ValueMap = containers.Map('KeyType', 'char','ValueType', 'single');
            for i = 1:length(measurementKeys)
                obj.ValueMap(measurementKeys(i)) = 0.0; % initialize with 0 
            end
            obj.OrderedKeys = measurementKeys;
        end
        
        function updateValue(obj, key, value)
            assert(isKey(obj.ValueMap,key))
            obj.ValueMap(key) = value;
        end
        
        function line = formatCsvLine(obj)
            values = [];
            for i = 1:length(obj.OrderedKeys)
                values = [values; obj.ValueMap(obj.OrderedKeys(i))];
            end
            
            line = datestr(now,'yyyy-mm-ddTHH:MM:SS.fff');
            line = line + sprintf(";%0.5g", values) + "\n";
        end
        
        function line = formatCsvHeader(obj)
            line = "Datetime" + sprintf(";%s", obj.OrderedKeys) + "\n";
        end
        
        function str = statusToStr(obj)
            lines = [];
            for i = 1:length(obj.OrderedKeys)
               lines = [lines; sprintf("  %20s: %.5g", obj.OrderedKeys(i), obj.ValueMap(obj.OrderedKeys(i)))];
            end
            
            str = sprintf("STATUS: "+newline+strjoin(cellstr(lines), newline)+newline+newline);
        end
    end
end

