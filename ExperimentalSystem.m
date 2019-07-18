classdef ExperimentalSystem<handle
    %EXPERIMENTALSYSTEM Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        MeasurementStorage
        RFBC
        LoadConnection
        SourceConnection
        Emulator
        CsvFilePath
    end
    
    properties(Constant)
        %use constants to avoid typos !!!
        SPANNUNG = "Spannung";
        STROM = "Strom";
        TEMP_ANOLYT = "Temperatur Anolyt";
        TEMP_KATOLYT = "Temperatur Katolyt";
        FLOW_ANOLYT = "Flowrate Anolyt";
        FLOW_KATOLYT = "Flowrate Katolyt";
        OCV = "OCV";
        LEISTUNG_BATTERIE = "Flowrate Anolyt";
        SOC = "SOC";
    end 
    
    methods
        function obj = ExperimentalSystem(rfbConnection, loadConnection, sourceConnection, emulator)
            %EXPERIMENTALSYSTEM Construct an instance of this class
            %   Detailed explanation goes here
            obj.RFBC = rfbConnection;
            obj.LoadConnection = loadConnection;
            obj.SourceConnection = sourceConnection;
            
            
            mKeys =  [
                ExperimentalSystem.SPANNUNG,...
                ExperimentalSystem.STROM,...
                ExperimentalSystem.TEMP_ANOLYT,...
                ExperimentalSystem.TEMP_KATOLYT,...
                ExperimentalSystem.FLOW_ANOLYT,...
                ExperimentalSystem.FLOW_KATOLYT,...
                ExperimentalSystem.OCV,...
                ExperimentalSystem.LEISTUNG_BATTERIE,...
                ExperimentalSystem.SOC
            ];
            obj.MeasurementStorage = MeasurementStorage(mKeys);
            obj.CsvFilePath = datestr(now,'yyyy-mm-ddTHH-MM-SS')+".csv";
            obj.appendOnCsvFile(obj.MeasurementStorage.formatCsvHeader());
            obj.runMeasurements();
        end
        
        function runExperiment(obj, loadCurve)
            %startup check (is WR ready) 
            %set WR Max values
            %while ! curve ended
            %    set constant power BMS
            %    set current or voltage WR
            %shutdown (disable load and WR)
            %stop battery
        end
        function runControlRoutine(obj)
            %while true 
            %   check errors MB
            %   check critical value MB
            %   check wanted current WR (check last updated)
            %   if critical
            %       shutdown
        end
        function runMeasurements(obj)
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
            obj.RFBC.getBatteryVoltage(...
                @(val)(obj.MeasurementStorage.updateValue(ExperimentalSystem.SPANNUNG, val)));
            
            obj.RFBC.getBatteryCurrent(...
                @(val)(obj.MeasurementStorage.updateValue(ExperimentalSystem.STROM, val)));
            
            obj.RFBC.getAnolytTemp(...
                @(val)(obj.MeasurementStorage.updateValue(ExperimentalSystem.TEMP_ANOLYT, val)));
            
            obj.RFBC.getKatolytTemp(...
                @(val)(obj.MeasurementStorage.updateValue(ExperimentalSystem.TEMP_KATOLYT, val)));
            
            obj.RFBC.getAnolytFlowrate(...
                @(val)(obj.MeasurementStorage.updateValue(ExperimentalSystem.FLOW_ANOLYT, val)));
            
            obj.RFBC.getKatolytFlowrate(...
                @(val)(obj.MeasurementStorage.updateValue(ExperimentalSystem.FLOW_KATOLYT, val)));
            
            obj.RFBC.getOpenCircuitVoltage(...
                @(val)(obj.MeasurementStorage.updateValue(ExperimentalSystem.OCV, val)));
            
            obj.RFBC.getBatteryPower(...
                @(val)(obj.MeasurementStorage.updateValue(ExperimentalSystem.LEISTUNG_BATTERIE, val)));
            
            obj.RFBC.getSOCRelative(...
                @(val)(obj.MeasurementStorage.updateValue(ExperimentalSystem.SOC, val)));
            
            line = obj.MeasurementStorage.formatCsvLine();
            obj.appendOnCsvFile(line);
            
            disp(obj.MeasurementStorage.statusToStr());
        end
       
    end
end

