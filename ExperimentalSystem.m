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
        
        ExperimentTimer 
        ControlTimer
    end
    
    properties(Constant)
        %use constants to avoid typos !!!
        SPANNUNG_BMS = "Spannung Bms";
        STROM_BMS = "Strom Bms";
        LEISTUNG_BMS = "Leistung Bms";
        TEMP_ANOLYT = "Temperatur Anolyt";
        TEMP_KATOLYT = "Temperatur Katolyt";
        FLOW_ANOLYT = "Flowrate Anolyt";
        FLOW_KATOLYT = "Flowrate Katolyt";
        OCV = "OCV";
        SOC = "SOC";
        
        STROM_QUELLE = "Strom Quelle";
        SPANNUNG_QUELLE = "Spannung Quelle";
        
        STROM_LAST = "Strom Last";
        SPANNUNG_LAST = "Spannung Last";
        
        STROM_VORGABE = "Strom Vorgabe";
        
        VOLTAGE_MIN = 10; %DO NOT CHANGE UNLESS YOU KNOW WHAT YOURE DOING
        VOLTAGE_MAX = 13;
        CURRENT_MAX = 10;
        FLOWRATE_MIN = 14;
        
        VALUE_TIMEOUT = 30; %TODO 3
        
        ERROR_WHITELIST = [10000, 10057, 10060];
    end 
    
    methods
        function obj = ExperimentalSystem(rfbConnection, loadConnection, sourceConnection)
            %EXPERIMENTALSYSTEM Construct an instance of this class
            %   Detailed explanation goes here
            obj.RFBC = rfbConnection;
            obj.LoadConnection = loadConnection;
            obj.SourceConnection = sourceConnection;
            %obj.Emulator = emulator; 
            
            
                
            mKeys =  [
                ExperimentalSystem.STROM_VORGABE,...
                ExperimentalSystem.STROM_QUELLE,...
                ExperimentalSystem.SPANNUNG_QUELLE,...
                ExperimentalSystem.STROM_LAST,...
                ExperimentalSystem.SPANNUNG_LAST,...
                ExperimentalSystem.SPANNUNG_BMS,...
                ExperimentalSystem.STROM_BMS,...
                ExperimentalSystem.LEISTUNG_BMS,...
                ExperimentalSystem.TEMP_ANOLYT,...
                ExperimentalSystem.TEMP_KATOLYT,...
                ExperimentalSystem.FLOW_ANOLYT,...
                ExperimentalSystem.FLOW_KATOLYT,...
                ExperimentalSystem.OCV,...
                ExperimentalSystem.SOC
            ];
        
            obj.MeasurementStorage = MeasurementStorage(mKeys, ExperimentalSystem.VALUE_TIMEOUT);
            obj.CsvFilePath = datestr(now,'yyyy-mm-ddTHH-MM-SS')+".csv";
            obj.appendOnCsvFile(obj.MeasurementStorage.formatCsvHeader());
        end
        
%         function singleStep()
%             
%         end
%         
        function runExperiment(obj, currentValues, interval) 
%             t = timer();
%             t.Name = "Experiment-Timer";
%             t.ExecutionMode = "fixedRate";
%             t.Period = interval;
%             t.TimerFcn = @(~,~)obj.singleStep();
%             t.ErrorFcn = @(~,~)obj.systemShutdown();
%             
%             obj.ExperimentTimer = t;
%             start(obj.ExperimentTimer);
%             
            
            %startup check (is WR ready)(Voltage between min and max)
            try
                %check connection and disable devices               
                obj.SourceConnection.Spannung = 0;
                obj.SourceConnection.Strom = 0;
                obj.SourceConnection.AusgangAn = false;
                obj.LoadConnection.Spannung = 0;
                obj.LoadConnection.Strom = 0;
                obj.LoadConnection.AusgangAn = false;    
                obj.LoadConnection.Mode = 'CURR';
                
                if any(abs(currentValues) > ExperimentalSystem.CURRENT_MAX)
                    throw(MException(Exceptions.VALUE_OOB_EXCEPTION, "Wanted current values must not exceed maximum current"));
                end
                
                %check rfb conditions
                obj.checkValuesInBounds();
                
                %Setting limit values 
                obj.LoadConnection.Spannungsbegrenzung = ExperimentalSystem.VOLTAGE_MIN;
                obj.SourceConnection.Spannung =  ExperimentalSystem.VOLTAGE_MAX;
                
                startTime = now;
                for i = 1:length(currentValues)
                    disp(datestr(now, 'HH:MM:SS.FFF'))
                 
                    current = currentValues(i);
%                     power = current*obj.MeasurementStorage.getValueChecked(ExperimentalSystem.SPANNUNG_LAST);
%                     obj.RFBC.putConstantPower(power, @NOOPCB);
                    
                    obj.MeasurementStorage.updateValue(ExperimentalSystem.STROM_VORGABE, current);
                    
                    if current < 0
                        obj.SourceConnection.Strom = 0;
                        obj.SourceConnection.AusgangAn = false;
                        obj.LoadConnection.Strom = abs(current);
                        obj.LoadConnection.AusgangAn = true;
                    else
                        obj.LoadConnection.Strom = 0;
                        obj.LoadConnection.AusgangAn = false;                        
                        obj.SourceConnection.Strom = abs(current);
                        obj.SourceConnection.AusgangAn = true;
                    end
                    fprintf("Current set to %.4g\n", current);
                    pTime = interval*i - etime(datevec(now), datevec(startTime));
                    pause(pTime); 
                end   
                obj.systemShutdown();
                
            catch e
                obj.systemShutdown();
                rethrow(e);
            end
        end

        function runControlRoutine(obj)
            t = timer;
            t.ExecutionMode = "fixedRate";
            t.Name = "Control-Timer";
            t.Period = 1;
            t.TimerFcn = @(~,~)(obj.singleControl());
            t.ErrorFcn = @(~,~)(obj.systemShutdown());
            start(t);
        end  
        
        function appendOnCsvFile(obj, line)
            fileID = fopen(obj.CsvFilePath, 'a');
            fprintf(fileID, line);
            fclose(fileID);
        end
        
        function handleAlarms(obj, alarms)
            %add unimportant Errors to the white list alarms if necessary
            %if any of the errors is not white listed the system will shut
            %down
            if any(~ismember(alarms, ExperimentalSystem.ERROR_WHITELIST))
                disp("Alarm detected")
                obj.systemShutdown();
            end
        end 
        
        function systemShutdown(obj)
            disp("Experimental System is shutting down");
            
            obj.SourceConnection.AusgangAn = false;
            obj.SourceConnection.Spannung = 0;
            obj.SourceConnection.Strom = 0;

            obj.LoadConnection.AusgangAn = false; 
            obj.LoadConnection.Spannung = 0;
            obj.LoadConnection.Strom = 0;
            
            fclose(obj.SourceConnection);
            fclose(obj.LoadConnection);
            %fclose(obj.Emulator);
        end

        function checkValuesInBounds(obj)
%             frKat = obj.MeasurementStorage.getValueChecked(ExperimentalSystem.FLOW_KATOLYT);
%             frAn = obj.MeasurementStorage.getValueChecked(ExperimentalSystem.FLOW_ANOLYT);
%             
%             if frKat < ExperimentalSystem.FLOWRATE_MIN
%                 throw(MException(Exceptions.VALUE_OOB_EXCEPTION, "Flowrate Katolyt too low"));
%             end
%             
%             if frAn < ExperimentalSystem.FLOWRATE_MIN
%                 throw(MException(Exceptions.VALUE_OOB_EXCEPTION, "Flowrate Anolyt too low"));
%             end
            
            spannung = obj.MeasurementStorage.getValueChecked(ExperimentalSystem.SPANNUNG_LAST);
            stromLast = obj.MeasurementStorage.getValueChecked(ExperimentalSystem.STROM_LAST);
            stromQuelle = obj.MeasurementStorage.getValueChecked(ExperimentalSystem.STROM_QUELLE);
            
            if spannung < ExperimentalSystem.VOLTAGE_MIN
                throw(MException(Exceptions.VALUE_OOB_EXCEPTION, "Voltage too low"));
            end
            
            if spannung > ExperimentalSystem.VOLTAGE_MAX
                throw(MException(Exceptions.VALUE_OOB_EXCEPTION, "Voltage too high"));
            end
            
            if stromLast > ExperimentalSystem.CURRENT_MAX
                throw(MException(Exceptions.VALUE_OOB_EXCEPTION, "Load current too high"));
            end
            
            if stromQuelle > ExperimentalSystem.CURRENT_MAX
                throw(MException(Exceptions.VALUE_OOB_EXCEPTION, "Source current too high"));
            end
            
            if obj.LoadConnection.AusgangAn && obj.SourceConnection.AusgangAn
                throw(MException(Exceptions.VALUE_OOB_EXCEPTION, "Forbidden state: Load and Source must not be activated at the same time"));
            end
            
            disp("Value check success");
        end
        
        function singleControl(obj)
            %query all values
            obj.RFBC.getAlarms(@obj.handleAlarms);
            
            obj.RFBC.getBatteryVoltage(...
                @(val)(obj.MeasurementStorage.updateValue(ExperimentalSystem.SPANNUNG_BMS, val)));
            
            obj.RFBC.getBatteryCurrent(...
                @(val)(obj.MeasurementStorage.updateValue(ExperimentalSystem.STROM_BMS, val)));
            
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
                @(val)(obj.MeasurementStorage.updateValue(ExperimentalSystem.LEISTUNG_BMS, val)));
            
            obj.RFBC.getSOCRelative(...
                @(val)(obj.MeasurementStorage.updateValue(ExperimentalSystem.SOC, val)));
            
            
            obj.MeasurementStorage.updateValue(ExperimentalSystem.SPANNUNG_QUELLE, obj.SourceConnection.SpannungMess);
            
            obj.MeasurementStorage.updateValue(ExperimentalSystem.STROM_QUELLE, obj.SourceConnection.StromMess);
            
            obj.MeasurementStorage.updateValue(ExperimentalSystem.SPANNUNG_LAST, obj.LoadConnection.SpannungMess);
            
            obj.MeasurementStorage.updateValue(ExperimentalSystem.STROM_LAST, obj.LoadConnection.StromMess);
            
            %checks measurements
            obj.checkValuesInBounds();
            
            %set emulator values
            %it is safe to substract the two currents here because it is
            %checked that load and source are not activated at the same
            %time
%             current = obj.MeasurementStorage.getValueChecked(ExperimentalSystem.STROM_QUELLE) - obj.MeasurementStorage.getValueChecked(ExperimentalSystem.STROM_LAST);
%             
%             obj.Emulator.setValues(...
%                 obj.MeasurementStorage.getValueChecked(ExperimentalSystem.SPANNUNG_LAST),...
%                 current);
           
            %output measurements
            line = obj.MeasurementStorage.formatCsvLine();
            obj.appendOnCsvFile(line);
            
            disp(obj.MeasurementStorage.statusToStr());
        end
       
    end
end

