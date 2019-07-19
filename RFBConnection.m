
classdef RFBConnection < MBUDPConnection
    %RFBCONNECTION Implementation of the functions used to controll the
    %Schmid RFB over modbus.

    methods(Access=public)  
        function getBatteryVoltage(obj, responseCB)
            obj.requestInputRegisterRead(5000, 2, "single", responseCB)
        end    
        
        function getBatteryCurrent(obj, responseCB)
            obj.requestInputRegisterRead(5004, 2, "single", responseCB)
        end     
        
        function getAnolytTemp(obj, responseCB)
            obj.requestInputRegisterRead(5012, 2, "single", responseCB)
        end  
        
        function getKatolytTemp(obj, responseCB)
            obj.requestInputRegisterRead(5016, 2, "single", responseCB)
        end  
        
        function getAnolytFlowrate(obj, responseCB)
            obj.requestInputRegisterRead(5028, 2, "single", responseCB)
        end  
        
        function getKatolytFlowrate(obj, responseCB)
            obj.requestInputRegisterRead(5032, 2, "single", responseCB)
        end  
        
        function getOpenCircuitVoltage(obj, responseCB)
            obj.requestInputRegisterRead(5068, 2, "single", responseCB)
        end  
        
        function getBatteryPower(obj, responseCB)
            obj.requestInputRegisterRead(5072, 2, "int32", responseCB)
        end
        
        function getSOCRelative(obj, responseCB)
            obj.requestInputRegisterRead(5076, 2, "single", responseCB)
        end
       
        function getConstantPower(obj, responseCB)
            obj.requestHoldingRegisterRead(1086, 2, "uint32", responseCB);
        end
       
        function getXtenderActive(obj, responseCB)
            obj.requestCoilRead(1134, 1, responseCB)
        end
        
        function getFlowRateControlActive(obj, responseCB)
            obj.requestCoilRead(1138, 1, responseCB)
        end
        
        function getACPowerControlActive(obj, responseCB)
            obj.requestCoilRead(1142, 1, responseCB)
        end
        
        function getAlarmHornActive(obj, responseCB)
            obj.requestCoilRead(1146, 1, responseCB)
        end
        
        function getCosPhiActive(obj, responseCB)
            obj.requestCoilRead(1150, 1, responseCB)
        end
        
        function getFlowStochiometryActive(obj, responseCB)
            obj.requestCoilRead(1162, 1, responseCB)
        end

        function getAlarms(obj, responseCB)
            boolRespCB = @(boolArray)(responseCB(obj.alarmListFromBoolArray(boolArray)));
            obj.requestCoilRead(10000, 66, boolRespCB)
        end
        
        function putSOCMax(obj, val, writeSuccessCB)
            obj.requestRegisterWrite(1070, val, writeSuccessCB)
        end
        
        function getSOCMax(obj, responseCB)
            obj.requestHoldingRegisterRead(1070, 1, "uint16", responseCB)
        end
        
        
        function putSOCMin(obj, val, writeSuccessCB)
            obj.requestRegisterWrite(1074, val, writeSuccessCB)
        end
        
        function getSOCMin(obj, responseCB)
            obj.requestHoldingRegisterRead(1074, 1, "uint16", responseCB)
        end
                
        function putFlowrateAnolyt(obj, val, writeSuccessCB)
            obj.requestMultipleRegisterWrite(1062, 2, single(val),writeSuccessCB)
        end         
        
        function putConstantPower(obj, val, writeSuccessCB)
            obj.requestMultipleRegisterWrite(1086, 2, uint32(val),writeSuccessCB)
        end
        
        function putButtonStart(obj, value, writeSuccessCB)
            obj.requestCoilWrite(9001, value, writeSuccessCB);
        end   
        
        function putButtonStop(obj, value, writeSuccessCB)
            obj.requestCoilWrite(9002, value, writeSuccessCB);
        end
        
        function putButtonReset(obj, value, writeSuccessCB)
            obj.requestCoilWrite(9003, value, writeSuccessCB);
        end
        
        function putButtonShutdown(obj, value, writeSuccessCB)
            obj.requestCoilWrite(9004, value, writeSuccessCB);
        end
        
    end
    
    methods(Access=private)
        function alarmArr = alarmListFromBoolArray(~, boolArray)
            %this automatically checks if the number of boolean values is
            %correct
            alarms = uint16(boolArray) .* uint16(10000:10065);
            alarmArr = alarms(alarms ~= 0);
        end
    end
end

