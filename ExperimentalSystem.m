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
        
        ControlTimer
        State
        
        Verbose
        
        PumpErrors;
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
        
        STROM_VORGABE_BMS = "Strom Vorgabe BMS";
        
        VOLTAGE_MIN = 50; %DO NOT CHANGE UNLESS YOU KNOW WHAT YOURE DOING
        VOLTAGE_MAX = 60;
        CURRENT_MAX = 10;
        FLOWRATE_MIN = 8;
        
        VALUE_TIMEOUT = 5; 
        
        ERROR_WHITELIST = [10000, 10057, 10060 : 10063, 10045, 10046, 10050 ,10002 ,10019, 10020, 10015, 10016];
        
        IDLE_RUN_POWER = 1000; %Emulated Power used for Idle runs
        IDLE_RUN_CURRENT = 8.888;
        IDLE_PUMPING_TIME = 45;
        PUMP_ERROR_CYCLES = 3;
    end 
    
    methods
        function obj = ExperimentalSystem(rfbConnection, loadConnection, sourceConnection, emulator, verbose)
            %EXPERIMENTALSYSTEM Construct an instance of this class
            %   Detailed explanation goes here
            obj.RFBC = rfbConnection;
            obj.LoadConnection = loadConnection;
            obj.SourceConnection = sourceConnection;
            obj.Emulator = emulator; 
            
            obj.State = States.STANDBY;
            
            obj.Verbose = verbose;
            
            obj.PumpErrors = 0;
            
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
        
        function runExperiment(obj, currentValues, interval) 
            %startup check (is WR ready)(Voltage between min and max)
            try
                logExp("Doing prechecks");
                %prechecks
                if any(abs(currentValues) > ExperimentalSystem.CURRENT_MAX)
                    throw(MException(Exceptions.VALUE_OOB_EXCEPTION, "Wanted current values must not exceed maximum current"));
                end
                
                if obj.MeasurementStorage.getValueChecked(ExperimentalSystem.SPANNUNG_LAST) > ExperimentalSystem.VOLTAGE_MAX || ...
                        obj.MeasurementStorage.getValueChecked(ExperimentalSystem.SPANNUNG_LAST) < ExperimentalSystem.VOLTAGE_MIN
                    throw(MException(Exceptions.VALUE_OOB_EXCEPTION, "Voltage is not in a safe range."));
                end
                
                %check connection and disarm devices               
                obj.SourceConnection.Spannung = 0;
                obj.SourceConnection.Strom = 0;
                obj.SourceConnection.AusgangAn = false;
                obj.LoadConnection.Spannung = 0;
                obj.LoadConnection.Strom = 0;
                obj.LoadConnection.AusgangAn = false;    
                obj.LoadConnection.Mode = 'CURR';
                
                %Setting limit values 
                obj.LoadConnection.Spannungsbegrenzung = ExperimentalSystem.VOLTAGE_MIN;
                obj.SourceConnection.Spannung =  ExperimentalSystem.VOLTAGE_MAX;
                
                if obj.State ~=States.STANDBY 
                    throw(MException(Exceptions.STATE_EXCEPTION, "System must be in Standby mode when experiment is started"));
                end
                
                logExp("System startup");
                obj.State = States.STARTUP;
                
                obj.RFBC.putConstantPower(ExperimentalSystem.IDLE_RUN_POWER, @NOOPCB);
                obj.RFBC.putButtonStart(1, @NOOPCB);
%                 
                logExp("Pumping electrolytes in idle mode");
                pause(ExperimentalSystem.IDLE_PUMPING_TIME);
                
                %check rfb conditions
                obj.checkValuesInBounds();
                
                logExp("Experiment running");
                obj.State = States.RUNNING;

                startTime = now;
                for i = 1:length(currentValues)
                    if obj.State ~= States.RUNNING
                       throw(MException(Exceptions.STATE_EXCEPTION, "System is not in running mode, values must not be set.\nExperiment aborted."));
                    end
                 
                    current = currentValues(i);
                    power = current*obj.MeasurementStorage.getValueChecked(ExperimentalSystem.SPANNUNG_LAST);
                    obj.RFBC.putConstantPower(abs(max(power,ExperimentalSystem.IDLE_RUN_POWER)), @NOOPCB);
                 
                    obj.MeasurementStorage.updateValue(ExperimentalSystem.STROM_VORGABE, current);
                    
                    if current < 0
                        obj.SourceConnection.Strom = 0;
                        obj.SourceConnection.AusgangAn = false;
                        obj.LoadConnection.Strom = abs(current);
                        obj.LoadConnection.AusgangAn = true;
                    elseif current > 0
                        obj.LoadConnection.Strom = 0;
                        obj.LoadConnection.AusgangAn = false;                        
                        obj.SourceConnection.Strom = abs(current);
                        obj.SourceConnection.AusgangAn = true;
                    else    
                        obj.LoadConnection.Strom = 0;
                        obj.LoadConnection.AusgangAn = false;                        
                        obj.SourceConnection.Strom = 0;
                        obj.SourceConnection.AusgangAn = false;
                    end
                    
                    logExp(sprintf("Current set to %.4g", current));
                    pTime = interval*i - etime(datevec(now), datevec(startTime));
                    pause(pTime); 
                end   
                
                logExp("Experiment ended successfuly");
                obj.systemShutdown();
                
            catch e
                logExp("Error in main routine");
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
            obj.ControlTimer = t;
            
            start(obj.ControlTimer);
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
            
            if obj.Verbose
                alarmStr = sprintf("%d,", alarms);
                logExp(sprintf("Alarms checked. Active alarms: %s", alarmStr));
            end
            
            
            if any(~ismember(alarms, ExperimentalSystem.ERROR_WHITELIST))
                logExp("Critical alarms detected");
                obj.systemShutdown();
            end
        end 
        
        function systemShutdown(obj)
            enterState = obj.State;
            if any(obj.State == [States.RUNNING, States.STARTUP, States.STANDBY]) %if system is running or in startup mode enter shutdown routine
                logExp("Experimental System shutdown");
                obj.State = States.SHUTDOWN; 
                stop(obj.ControlTimer);
                
                current = ExperimentalSystem.IDLE_RUN_CURRENT;

                obj.Emulator.setValues(...
                    obj.MeasurementStorage.getValueChecked(ExperimentalSystem.SPANNUNG_LAST),...
                    current);
                
                obj.RFBC.putConstantPower(ExperimentalSystem.IDLE_RUN_POWER, @NOOPCB);
                
                if any(enterState == [States.RUNNING, States.STARTUP])
                    obj.SourceConnection.AusgangAn = false;
                    obj.SourceConnection.Spannung = 0;
                    obj.SourceConnection.Strom = 0;

                    obj.LoadConnection.AusgangAn = false; 
                    obj.LoadConnection.Spannung = 0;
                    obj.LoadConnection.Strom = 0; 

                    logExp("Pumping electrolytes in idle mode");
                    pause(ExperimentalSystem.IDLE_PUMPING_TIME);
                end

                logExp("Stopping RFBC");
                obj.RFBC.putButtonStop(true, @NOOPCB);
                obj.RFBC.putButtonStop(true, @NOOPCB);
                obj.RFBC.putButtonStop(true, @NOOPCB);

                obj.LoadConnection.close();
                obj.SourceConnection.close();
                obj.RFBC.close();
                fclose(obj.Emulator);
                
                obj.State = States.STOPPED;
                logExp("System stopped");
            else
                logExp("System is already shut down or shutting down");
            end
          
        end

        function checkValuesInBounds(obj)
            if obj.State == States.RUNNING
                frKat = obj.MeasurementStorage.getValueChecked(ExperimentalSystem.FLOW_KATOLYT);
                frAn = obj.MeasurementStorage.getValueChecked(ExperimentalSystem.FLOW_ANOLYT);

                if frKat < ExperimentalSystem.FLOWRATE_MIN || frAn < ExperimentalSystem.FLOWRATE_MIN
                    logExp("WARNING: Flowrate too low");
                    obj.PumpErrors = obj.PumpErrors +1;
                else
                    obj.PumpErrors = 0;
                end

                if obj.PumpErrors >= ExperimentalSystem.PUMP_ERROR_CYCLES
                    throw(MException(Exceptions.VALUE_OOB_EXCEPTION, sprintf("Flowrate too low for more than %d control cycles", ExperimentalSystem.PUMP_ERROR_CYCLES)));
                end
                    
            end
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
            
            if obj.Verbose
                logExp("Value check success");
            end
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
            if any(obj.State == [States.STARTUP, States.SHUTDOWN])
                current = ExperimentalSystem.IDLE_RUN_CURRENT;
            else
                current = obj.MeasurementStorage.getValueChecked(ExperimentalSystem.STROM_QUELLE) - obj.MeasurementStorage.getValueChecked(ExperimentalSystem.STROM_LAST);
                absCur = max(ExperimentalSystem.IDLE_RUN_CURRENT, abs(current));
                current = sign(current) * absCur;
            end
            obj.Emulator.setValues(...
                obj.MeasurementStorage.getValueChecked(ExperimentalSystem.SPANNUNG_LAST),...
                current);


           
            %output measurements
            line = obj.MeasurementStorage.formatCsvLine();
            obj.appendOnCsvFile(line);
            
            %disp(obj.MeasurementStorage.statusToStr());
        end
       
    end
end

