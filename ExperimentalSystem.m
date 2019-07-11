classdef ExperimentalSystem<handle
    %EXPERIMENTALSYSTEM Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        MeasurementStorage
        RFBC
        CsvFilePath
    end
    
    methods
        function obj = ExperimentalSystem()
            %EXPERIMENTALSYSTEM Construct an instance of this class
            %   Detailed explanation goes here
            obj.RFBC = RFBConnection("141.76.14.122",502, 1, 1);
            mKeys =  ["Spannung", "Strom", "Anolyt Temp", "Katolyt Temp", "Anolyt Flowrate", "Katolyt Flowrate", "OCV", "Batterie Leistung", "SOC"];
            obj.MeasurementStorage = MeasurementStorage(mKeys);
            obj.CsvFilePath = datestr(now,'yyyy-mm-ddTHH-MM-SS')+".csv";
            obj.appendOnCsvFile(obj.MeasurementStorage.formatCsvHeader());
            obj.runMeasurementWriter();
        end
        
        function runMeasurementWriter(obj)
            t = timer;
            t.ExecutionMode = "fixedRate";
            t.Period = 0.5;
            t.TimerFcn = @(~,~)obj.singleMeasurement();
            start(t);
        end  
        
        function appendOnCsvFile(obj, line)
            fileID = fopen(obj.CsvFilePath, 'a');
            fprintf(fileID, line);
            fclose(fileID);
        end

        function singleMeasurement(obj)
            obj.RFBC.getBatteryVoltage(@(val)(obj.MeasurementStorage.updateValue("Spannung", val)));
            obj.RFBC.getBatteryCurrent(@(val)(obj.MeasurementStorage.updateValue("Strom", val)));
            obj.RFBC.getAnolytTemp(@(val)(obj.MeasurementStorage.updateValue("Anolyt Temp", val)));
            obj.RFBC.getKatolytTemp(@(val)(obj.MeasurementStorage.updateValue("Katolyt Temp", val)));
            obj.RFBC.getAnolytFlowrate(@(val)(obj.MeasurementStorage.updateValue("Anolyt Flowrate", val)));
            obj.RFBC.getKatolytFlowrate(@(val)(obj.MeasurementStorage.updateValue("Katolyt Flowrate", val)));
            obj.RFBC.getOpenCircuitVoltage(@(val)(obj.MeasurementStorage.updateValue("OCV", val)));
            obj.RFBC.getBatteryPower(@(val)(obj.MeasurementStorage.updateValue("Batterie Leistung", val)));
            obj.RFBC.getSOCRelative(@(val)(obj.MeasurementStorage.updateValue("SOC", val)));
            
            line = obj.MeasurementStorage.formatCsvLine();
            obj.appendOnCsvFile(line);
            
            disp(obj.MeasurementStorage.statusToStr());
        end
       
    end
end

