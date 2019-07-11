classdef WREmulator<handle
    
    properties(Constant)
        BAUDRATE = 38400;
        PARITY = "even";
        
        STATIC_RESPONSES = WREmulator.builtStaticResponseMap(); %static method to keep code clean
        READ_MESSAGE_RESPONSE = [170, 54, 245, 1, 0, 0, 1, 0, 0, 0, 28, 0, 72, 32, 2, 1, 3, 0, 0, 0, 0, 0, 0, 0, 208, 3, 0, 0, 3, 0, 101, 0, 0, 0, 211, 168, 137, 92, 0, 0, 0, 0, 160, 112];
   
        OP_MODE_INVERTER = 1;
        OP_MODE_CHARGING = 2;
        OP_MODE_INJECTION = 4;
    end
    
    properties
        XcomPort
        ManagementPort
        
        ACInputPower
        ACOutputPower
        DCVoltage
        DCCurrent
        OperatingMode
        InverterActive
    end
    
    
    
    methods
        function obj = WREmulator(xcomPortName, managementPortName)
            s1 = serial(xcomPortName);
            s1.Baudrate = WREmulator.BAUDRATE;
            s1.Parity = WREmulator.PARITY;
            s1.BytesAvailableFcnCount = 14;
            s1.BytesAvailableFcnMode = 'byte';
            s1.BytesAvailableFcn = @onRequest; %TODO
            fopen(s1);
            
            obj.XcomPort = s1;
            disp("Connection to xcom opened");
            
            s2 = serial(managementPortName);
            s2.Baudrate = WREmulator.BAUDRATE;
            s2.Parity = WREmulator.PARITY;
            s2.BytesAvailableFcnCount = 14;
            s2.BytesAvailableFcnMode = 'byte';
            s2.BytesAvailableFcn = @onRequest;
            fopen(s2);
            
            obj.ManagementPort = s2;
            disp("Connection to bms opened");
            %TODO explicit open ports
            
            obj.ACInputPower = single(0);
            obj.ACOutputPower = single(0);
            obj.DCVoltage = single(0);
            obj.DCCurrent = single(0);
            obj.OperatingMode = 2;
            obj.InverterActive = 0;
        end
        
        function delete(obj)
            fclose(obj.XcomPort);
            delete(obj.XcomPort);
            disp("Xcom serial port closed")
        
            fclose(obj.XcomPort);
            delete(obj.XcomPort);
            disp("BMS serial port closed")
        end
    end
    
    methods(Access=private)
        function response = emulateResponse(request)
            if request.ServiceId == 1
                response = emulateWriteResponse(request);
            elseif request.ServiceId == 2
                response = emulateWriteResponse(request);
            else
                throw(MException(Exceptions.RESPONSE_NOT_DEFINED_EXCEPTION));
            end
        end
        
        function response = emulateWriteResponse(request)
            %optionela st current and discharge current
            
            obj.sendMessage(obj.XcomPort, request); %forward to WR
            obj.receiveMessage(obj.XcomPort); %drop response
            
            response = SerialMessage(...
                SerialMessage.FRAME_FLAGS_RESPONSE,...
                request.DestAddress,...
                request.SrcAddress,...
                SerialMessage.SERVICE_FLAG_IS_RESPONSE,...
                request.ServiceId,...
                request.ObjectType,...
                request.ObjectId,...
                request.PropertyId,...
                []...
            );
        end 
        
        function response = emulateParamUserInfoReadResponse(request)
            key = WREmulator.combineKey(request.ObjectId, request.PropertyId);
            if isKey(WREmulator.STATIC_RESPONSES, key)
                % if static response is defined, get response from Map and
                % return
                response = SerialMessage.fromBytes(WREmulator.STATIC_RESPONSES(key));
                return
            end    
                
            
            %...otherwise create response from last known values
            propertyDataBytes = [];    
            if request.ObjectId == 3000 && request.PropertyId == 1
                propertyDataBytes = typecast(single(obj.DCVoltage), "uint8");
                
            elseif request.ObjectId == 3004 && request.PropertyId == 1
                propertyDataBytes = typecast(single(obj.DCCurrent), "uint8");
                
            elseif request.ObjectId == 3005 && request.PropertyId == 1
                propertyDataBytes = typecast(single(obj.DCCurrentWanted), "uint8");
                
            elseif request.ObjectId == 3028 && request.PropertyId == 1
                propertyDataBytes = typecast(uint16(obj.OperatingMode), "uint8");
                
            elseif request.ObjectId == 3049 && request.PropertyId == 1
                propertyDataBytes = typecast(uint16(obj.InverterState), "uint8");
                
            elseif request.ObjectId == 3136 && request.PropertyId == 1
                propertyDataBytes = typecast(single(obj.ACOutputPower), "uint8");
                
            elseif request.ObjectId == 3137 && request.PropertyId == 1
                propertyDataBytes = typecast(single(obj.ACInputPower), "uint8");
            else
                throw(MException(Exceptions.RESPONSE_NOT_DEFINED_EXCEPTION));
            end
            
            response = SerialMessage(...
                SerialMessage.FRAME_FLAGS_RESPONSE,...
                request.DestAddress,...
                request.SrcAddress,...
                SerialMessage.SERVICE_FLAG_IS_RESPONSE,...
                request.ServiceId,...
                request.ObjectType,...
                request.ObjectId,...
                request.PropertyId,...
                propertyDataBytes...
            );
        end
        
        function response = emulateReadResponse(request)
            if any(request.ObjectType == [1,2])
                response = obj.emulateParamUserInfoReadResponse(request);
            elseif request.ObjectType == 3
                response = SerialMessage.fromBytes(WREmulator.READ_MESSAGE_RESPONSE);
            else
                throw(MException(Exceptions.RESPONSE_NOT_DEFINED_EXCEPTION));
            end
        end
        
        function msg = receiveMessage(port)
            headerBytes = fread(port, 14);
            assert(headerBytes(0) == hex2dec("AA"));
            
            dataLen = SerialMessage.parseDataLength(headerBytes);
            dataBytes = fread(obj.ManagementPort, dataLen);
            
            checksumBytes = fread(obj.ManagementPort, 2);
            msgBytes = [headerBytes, dataBytes, checksumBytes];
            
            msg = SerialMessage.fromBytes(msgBytes);
        end
        
        function sendMessage(port, msg)
            fwrite(port, msg.toBytes());
        end
        
        function onRequest( ~, ~)
           while obj.ManagementPort.BytesAvailable >= 14
               request = obj.receiveMessage(obj.ManagementPort);
               disp(request.toStr())
               
               assert(request.ServiceFlags == 0) %all messages received must be requests
               
               fwdEmu = [];
               try
                   response = obj.emulateResponse(request);
                   fwdEmu = "Emulated";
               catch ME
                   if strcmp(ME.identifier, Exceptions.RESPONSE_NOT_DEFINED_EXCEPTION)
                       fwdEmu = "Forwarded";
                       obj.sendMessage(obj.XcomPort, request);
                       response = obj.receiveMessage(obj.XcomPort);
                   else
                       ME.rethrow();
                   end
               end
               
               obj.sendMessage(obj.ManagementPort, response);
               
               % print response
               disp(fwdEmu);
               if ismember(response.ObjectId, [3000, 3004, 3005])
                   disp(response.toStr("single"))
               else
                   disp(response.toStr())
               end
               
               %log request and response
               ts = datestr(now,'yyyy-mm-ddTHH:MM:SS.FFF');
               msgLogFile = fopen('msg_log.csv', 'a+');
               fprintf(msgLogFile, '%s;%s;%s\n', ts, request.formatCsvLine(), fwdEmu);
               fprintf(msgLogFile, '%s;%s;%s\n', ts, response.formatCsvLine(), fwdEmu);
               fclose(msgLogFile);
           end
        end
    end
    
    methods(Static, Access=public)
        function key = combineKey(a, b)
            offset = uint64(intmax('uint32'))+1;
            
            key = uint64(a) * offset + uint64(b);
        end
        
        function map = builtStaticResponseMap()
            map = containers.Map('KeyType', 'uint64','ValueType', 'any');
            
            map(WREmulator.combineKey(5101, 5)) = [170, 54, 245, 1, 0, 0, 1, 0, 0, 0, 14, 0, 58, 4, 2, 1, 2, 0, 237, 19, 0, 0, 5, 0, 2, 0, 0, 0, 11, 70];
            map(WREmulator.combineKey(1610, 13)) = [170, 54, 100, 0, 0, 0, 1, 0, 0, 0, 11, 0, 165, 75, 2, 1, 2, 0, 74, 6, 0, 0, 5, 0, 0, 89, 96];
            map(WREmulator.combineKey(1623, 13)) = [170, 54, 100, 0, 0, 0, 1, 0, 0, 0, 14, 0, 168, 81, 2, 1, 2, 0, 87, 6, 0, 0, 5, 0, 0, 0, 0, 0, 102, 237];
            map(WREmulator.combineKey(1613, 13)) = [170, 54, 100, 0, 0, 0, 1, 0, 0, 0, 14, 0, 168, 81, 2, 1, 2, 0, 77, 6, 0, 0, 5, 0, 0, 0, 72, 66, 230, 91];
            map(WREmulator.combineKey(1622, 13)) = [170, 54, 100, 0, 0, 0, 1, 0, 0, 0, 14, 0, 168, 81, 2, 1, 2, 0, 86, 6, 0, 0, 5, 0, 0, 0, 0, 0, 101, 227];
            map(WREmulator.combineKey(1624, 13)) = [170, 54, 100, 0, 0, 0, 1, 0, 0, 0, 14, 0, 168, 81, 2, 1, 2, 0, 88, 6, 0, 0, 5, 0, 0, 192, 204, 61, 48, 12];
            map(WREmulator.combineKey(3124, 1)) = [170, 54, 100, 0, 0, 0, 1, 0, 0, 0, 14, 0, 168, 81, 2, 1, 1, 0, 52, 12, 0, 0, 1, 0, 0, 0, 128, 63, 3, 224];
            map(WREmulator.combineKey(3125, 1)) = [170, 54, 100, 0, 0, 0, 1, 0, 0, 0, 14, 0, 168, 81, 2, 1, 1, 0, 53, 12, 0, 0, 1, 0, 0, 64, 156, 69, 102, 232];
            map(WREmulator.combineKey(3126, 1)) = [170, 54, 100, 0, 0, 0, 1, 0, 0, 0, 14, 0, 168, 81, 2, 1, 1, 0, 54, 12, 0, 0, 1, 0, 0, 0, 102, 67, 239, 196];
            map(WREmulator.combineKey(3127, 1)) = [170, 54, 100, 0, 0, 0, 1, 0, 0, 0, 14, 0, 168, 81, 2, 1, 1, 0, 55, 12, 0, 0, 1, 0, 0, 0, 64, 66, 201, 129];
            map(WREmulator.combineKey(3128, 1)) = [170, 54, 100, 0, 0, 0, 1, 0, 0, 0, 14, 0, 168, 81, 2, 1, 1, 0, 56, 12, 0, 0, 1, 0, 0, 0, 176, 65, 57, 106];
            map(WREmulator.combineKey(3129, 1)) = [170, 54, 100, 0, 0, 0, 1, 0, 0, 0, 14, 0, 168, 81, 2, 1, 1, 0, 57, 12, 0, 0, 1, 0, 0, 80, 32, 69, 254, 72];
            map(WREmulator.combineKey(3130, 1)) = [170, 54, 100, 0, 0, 0, 1, 0, 0, 0, 14, 0, 168, 81, 2, 1, 1, 0, 58, 12, 0, 0, 1, 0, 0, 0, 128, 67, 13, 32];
            map(WREmulator.combineKey(3131, 1)) = [170, 54, 100, 0, 0, 0, 1, 0, 0, 0, 14, 0, 168, 81, 2, 1, 1, 0, 59, 12, 0, 0, 1, 0, 0, 192, 195, 68, 18, 241];
            map(WREmulator.combineKey(3132, 1)) = [170, 54, 100, 0, 0, 0, 1, 0, 0, 0, 14, 0, 168, 81, 2, 1, 1, 0, 60, 12, 0, 0, 1, 0, 0, 0, 0, 68, 144, 53];
            map(WREmulator.combineKey(3156, 1)) = [170, 54, 100, 0, 0, 0, 1, 0, 0, 0, 14, 0, 168, 81, 2, 1, 1, 0, 84, 12, 0, 0, 1, 0, 0, 224, 138, 70, 20, 219];
            map(WREmulator.combineKey(3157, 1)) = [170, 54, 100, 0, 0, 0, 1, 0, 0, 0, 14, 0, 168, 81, 2, 1, 1, 0, 85, 12, 0, 0, 1, 0, 0, 64, 16, 68, 249, 15];
        end
    end 
end

