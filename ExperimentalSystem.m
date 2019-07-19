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
        
        STROM_QUELLE = "Strom Quelle";
        SPANNUNG_QUELLE = "Spannung Quelle";
        
        STROM_LAST = "Strom Last";
        SPANNUNG_LAST = "Spannung Last";
        
        VOLTAGE_MIN = 48; %DO NOT CHANGE UNLESS YOU KNOW WHAT YOURE DOING
        VOLTAGE_MAX = 56;
        
        CURRENT_MAX = 10;
        
        FLOWRATE_MIN = 14;
    end 
    
    methods
        function obj = ExperimentalSystem(rfbConnection, loadConnection, sourceConnection, emulator, interval)
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
        end
        
        function runExperiment(obj, currentValues)
            %startup check (is WR ready)(Voltage between min and max)
            try
                %check connection and disable devices               
                obj.SourceConnection.Spannung = 0;
                obj.SourceConnection.Strom = 0;
                obj.SourceConnection.AusgangAn = false;
                obj.LoadConnection.Spannung = 0;
                obj.LoadConnection.Spannung = 0;
                obj.LoadConnection.AusgangAn = false;    
                obj.LoadConnection.Mode = "CURR";
                
                %check rfb conditions
                obj.checkValuesInBounds();
                
                %Setting limit values 
                obj.LoadConnection.Spannungsbegrenzung = ExperimentalSystem.VOLTAGE_MIN;
                obj.SourceConnection.Spannung =  ExperimentalSystem.VOLTAGE_MAX;
                
                for i = 1:length(currentValues)
                    current = currentValues(i);
                    power = current*obj.MeasurementStorage.getValueChecked(ExperimentalSystem.SPANNUNG_LAST);
                    obj.RFBC.putConstantPower(power, @NOOPCB);
                    
                    if current < 0
                        obj.SourceConnection.Strom = 0;
                        obj.SourceConnection.AusgangAn = false;
                        obj.LoadConnection.Strom = current;
                        obj.LoadConnection.AusgangAn = true;
                    else
                        obj.LoadConnection.Strom = 0;
                        obj.LoadConnection.AusgangAn = false;                        
                        obj.SourceConnection.Strom = current;
                        obj.SourceConnection.AusgangAn = false;
                    end
                    pause(obj.Interval); 
                end 
                
            catch e
                obj.emergencyShutdown();
                rethrow(e);
            end
            %set 
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
            %set emulator values
            %   if critical
            %       shutdown
        end
        function runControlRoutine(obj)
            t = timer;
            t.ExecutionMode = "fixedRate";
            t.Period = 1;
            t.TimerFcn = @(~,~)obj.singleControl();
            start(t);
        end  
        
        function appendOnCsvFile(obj, line)
            fileID = fopen(obj.CsvFilePath, 'a');
            fprintf(fileID, line);
            fclose(fileID);
        end
        
        function handleAlarms(obj, alarmList)
            %exclude unimportant alarms if neceary
            if isempty(alarmList)
                obj.emergencyShutdown();
                
            end
        end 
        
        function emergencyShutdown(obj)
            obj.SourceConnection.Spannung = 0;
            obj.SourceConnection.Strom = 0;
            obj.SourceConnection.AusgangAn = false;
            obj.LoadConnection.Spannung = 0;
            obj.LoadConnection.Spannung = 0;
            obj.LoadConnection.AusgangAn = false; 
        end

        function val = checkValuesInBounds(obj)
            frKat = obj.MeasurementStorage.getValueChecked(ExperimentalSystem.FLOW_KATOLYT);
            frAn = obj.MeasurementStorage.getValueChecked(ExperimentalSystem.FLOW_ANOLYT);
            
            if frKat < ExperimentalSystem.FLOWRATE_MIN
                throw(MExeption(Exceptions.VALUE_OOB_EXCEPTION, "Flowrate Katolyt too low"));
            end
            
            if frAn < ExperimentalSystem.FLOWRATE_MIN
                throw(MExeption(Exceptions.VALUE_OOB_EXCEPTION, "Flowrate Anolyt too low"));
            end
            
            %%%% TODO implemtn other checks
            
        end
        
        function singleControl(obj)
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
            
            obj.RFBC.getAlarms(@obj.
            
            line = obj.MeasurementStorage.formatCsvLine();
            obj.appendOnCsvFile(line);
            
            disp(obj.MeasurementStorage.statusToStr());
        end
       
    end
end

