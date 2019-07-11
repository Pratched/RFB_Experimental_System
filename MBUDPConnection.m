classdef MBUDPConnection < handle
    %MBUDPCONNECTION Implementation of a Modbus UDP Connection and the MB
    %protocoll functions.
    
    properties
        UDPConnection
        PendingRequests 
        NextTID
        UnitID
        ResponseTimeout
    end
    
    methods(Access=public)
         function obj = MBUDPConnection(host, port, unitID, responseTimeOut)
             u = udp(host, port);
             u.TimeOut = 2;
             u.BytesAvailableFcnCount = 7;
             u.BytesAvailableFcnMode = "byte";
             u.BytesAvailableFcn = @obj.onReceivedHeader;
             fopen(u);
             disp("UDP Connection opened")
             
             obj.UDPConnection = u;
             obj.NextTID = 1337;
             obj.UnitID = unitID;
             obj.PendingRequests = containers.Map('KeyType', 'int32','ValueType', 'any');
             obj.ResponseTimeout = responseTimeOut;
         end


        function delete(obj)
            fclose(obj.UDPConnection);
            delete(obj.UDPConnection);
            disp("UDP Connection closed")
        end
        
        function bytes = swapByteOrder(~, bytes)
            %SWAPBYTEORDER Swaps bytes in a byte array according to the
            %Modbus specification.
            %   Swaps bytes every 2 bytes (register length =16bit) ABCD ->
            %   BADC
            bytes = typecast(swapbytes(typecast(bytes, "uint16")), "uint8");
        end
    end
    
    methods(Access=protected)
                
        function requestCoilRead(obj, startAddress, nCoils, responseCB)
            %REQUESTCOILREAD Implementation of modbus function
            %0x01
            tid = obj.getNextTID();
            dataBytes = [
                obj.uint16Bytes(startAddress),...
                obj.uint16Bytes(nCoils)
            ];
            msg = obj.serializeTCPMessage(tid, 1, dataBytes);

            rawBytesCB = @(respBytes)(responseCB(obj.parseBooleanValues(respBytes(2:end), nCoils)));
            
            obj.sendRequest(msg, tid, rawBytesCB);
        end
        
        function requestHoldingRegisterRead(obj, startAddress, nRegisters, dType, responseCB)
            %REQUESTHOLDINGREGISTERREAD Implementation of modbus function
            %0x03
            obj.requestRegisterRead(3, startAddress, nRegisters, dType, responseCB);
        end
        
        function requestInputRegisterRead(obj, startAddress, nRegisters, dType, responseCB)
            %REQUESTINPUTREGISTERREAD Implementation of modbus function
            %0x04
            obj.requestRegisterRead(4, startAddress, nRegisters, dType, responseCB);
        end
        
        function requestCoilWrite(obj, address, value, writeSuccessCB)
            %REQUESTCOILWRITE Implementation of modbus function
            %0x05
            tid = obj.getNextTID();
            assert(value == 0 || value == 1)
            
            dataBytes = [
                obj.uint16Bytes(address),...
                uint8(value * [255, 0])
            ];
            msg = obj.serializeTCPMessage(tid, 5, dataBytes);

            rawBytesCB = @(respBytes)(writeSuccessCB(all(respBytes == transpose(dataBytes))));
            
            obj.sendRequest(msg, tid, rawBytesCB);
        end

        function requestRegisterWrite(obj, address, value,writeSuccessCB)
            %REQUESTREGISTERWRITE Implementation of modbus function
            %0x06
            tid = obj.getNextTID();
            dataBytes = [
                obj.uint16Bytes(address),...
                obj.uint16Bytes(value)
            ];
            msg = obj.serializeTCPMessage(tid, 6, dataBytes);

            rawBytesCB = @(respBytes)(writeSuccessCB(all(respBytes == transpose(dataBytes))));
            
            obj.sendRequest(msg, tid, rawBytesCB);
        end
        
        function requestMultipleRegisterWrite(obj, address, nRegisters, value,writeSuccessCB)
            %REQUESTMULTIPLEREGISTERWRITE Implementation of modbus function
            %0x16
            tid = obj.getNextTID();
            nBytesValue = uint8(nRegisters*2);
            valueBytes = obj.swapByteOrder(typecast(value, "uint8"));
            
            assert(length(valueBytes) == nBytesValue)
            
            dataBytes = [
                obj.uint16Bytes(address),...
                obj.uint16Bytes(nRegisters),...
                nBytesValue,...
                valueBytes
            ];
            msg = obj.serializeTCPMessage(tid, 16, dataBytes);
                
            rawBytesCB = @(respBytes)(writeSuccessCB(all(respBytes == transpose(dataBytes(1:4)))));
            
            obj.sendRequest(msg, tid, rawBytesCB);
        end
    end
    
    methods(Access=private)   
        function requestRegisterRead(obj, fCode, startAddress, nRegisters, dType, responseCB)
            %REQUESTREGISTERREAD Helper function for MB function 0x03 and
            %0x04
            tid = obj.getNextTID();
            
            assert(fCode == 3 || fCode == 4)
            
            dataBytes = [
                obj.uint16Bytes(startAddress),...
                obj.uint16Bytes(nRegisters)
            ];
        
            msg = obj.serializeTCPMessage(tid, fCode, dataBytes);
            rawBytesCB = @(respBytes)(responseCB(typecast(obj.swapByteOrder(respBytes(2:end)), dType)));
            obj.sendRequest(msg, tid, rawBytesCB);
        end
        
        function cleanUpCallback(obj, tid)
            %CLEANUPCALLBACK CB that is invoked after a request times out.
            %   Deletes the response callback from the map and prints a
            %   message.
            if isKey(obj.PendingRequests, tid)
                fprintf("WARNING: Request with tid %d did not get a response\n", tid)
                remove(obj.PendingRequests, tid);
            end
        end
        
        function onReceivedHeader(obj, ~, ~)
            %ONRECEIVEDHEADER CB that is invoked when the UDP connection has received
            %more than 7 bytes. (Length of MBAP Header = 7 byte)
            %   Reads full message, does consistency checks and passes the
            %   databytes to the databyte callback.
            while obj.UDPConnection.BytesAvailable >= 7
                data = fread(obj.UDPConnection);
                data = uint8(data);
                dataLenBytes = data(5:6);
                dataLen = obj.bytesToUint16(dataLenBytes);
                tid_bytes = data(1:2);
                tid = obj.bytesToUint16(tid_bytes);
                
                % check for modbus errors
                assert( dataLen == length(data)-6)
                % check if response is indicating an error
                assert( bitget(data(8), 8) == 0)
                
                %disp("data")
                %disp(data)
                
                try    
                    responseCB = obj.PendingRequests(tid);
                    try    
                        %data = obj.swapByteOrder(data(10:end));
                        data = data(9:end);
                    catch
                        disp("Data cannot be extracted from response");
                        data = [];
                    end
                    try
                        responseCB(data);
                    catch e
                        fprintf(1,'Error excuting response callback: %s\n',e.message);
                    end
                catch 
                    disp("Unrequested message received")
                end
                remove(obj.PendingRequests, tid);
            end
        end
        
        function sendRequest(obj, requestBytes, tid, rawResponseCb)
            %SENDREQUEST Sends message over UDP connection.
            %   DONT USE DIRECTLY BUT USE MB FUNCTIONS INSTEAD.
            %   Sends message bytes and schedules a time out for the
            %   response.
            obj.PendingRequests(tid) = rawResponseCb;
            fwrite(obj.UDPConnection, requestBytes);
            %disp("Bytes written at UDP Connection")
            %disp(requestBytes)
            
            % schedule response timeout
            t = timer;
            t.ExecutionMode = "singleShot";
            t.StartDelay = obj.ResponseTimeout;
            t.TimerFcn = @(~,~)obj.cleanUpCallback(tid);
            start(t);
        end
        
        
        function id = getNextTID(obj)
            %GETNEXTTID Returns next transaction ID and increases counter by 1. 
            id = obj.NextTID;
            obj.NextTID = obj.NextTID + 1;
        end
        
        function msg = serializeTCPMessage(obj, tID, fCode, dataBytes)
            %SERIALIZETCPMESSAGE  Function to serialize a message in the
            %Modbus/TCP format.
            %   Returns byte array of the serialized message.
            tid = obj.uint16Bytes(tID);
            protocollID = uint8([0, 0]);
            dataLen = obj.uint16Bytes(length(dataBytes)+2); % +1 for function code +1 for unit ID
            unitID = uint8(obj.UnitID);
            
            fCode = uint8(fCode);
            
            msg = [tid, protocollID, dataLen, unitID, fCode, dataBytes];
        end
        
        function bytes = uint16Bytes(obj, number)
            %UINT16BYTES Converts a number to a 2 byte array. 
            %   16bit integers are commonly used in the MB protocol.
            bytes = obj.swapByteOrder(typecast(uint16(number), "uint8"));
        end
        
        function number = bytesToUint16(obj, bytes)
            %BYTESTOUINT16 Converts a 2 byte array to a 16 bit integer.
            number = typecast(obj.swapByteOrder(bytes), "uint16");
        end

        function  val = parseBooleanValues(~, bytes, nValues)
            %PARSEBOOLEANVALUES Converts byte array to array of single
            %boolean values.
            boolVector = transpose(de2bi(bytes,8));
            val = boolVector(1:nValues);
            assert(all(boolVector(nValues+1:end) == 0))
             
        end
        

    end
end

