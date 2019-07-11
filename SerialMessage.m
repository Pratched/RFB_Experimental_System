classdef SerialMessage<handle
    %SERIALMESSAGE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(Constant, Hidden)
        SID_READ  = uint8(1);
        SID_WRITE = uint8(2);
        
        SERVICE_FLAG_IS_RESPONSE = uint8(bin2dec("00000010")); % Have to be added if Response is Error
        
        SERVICE_FLAG_IS_ERROR = uint8(bin2dec("00000001"));
        
        FRAME_FLAGS_RESPONSE = uint8(bin2dec("00110110"));
    end
    
    properties
        FrameFlags
        SrcAddress
        DestAddress
        ServiceFlags
        ServiceId
        ObjectType
        ObjectId
        PropertyId
        PropertyDataBytes
    end
    
    methods(Access=public)
        function obj = SerialMessage(frameFlags, srcAddress, destAddress, serviceFlags, serviceId, objectType, objectId, propertyId, propertyDataBytes)
            obj.FrameFlags = uint8(frameFlags);
            obj.SrcAddress = uint32(srcAddress);
            obj.DestAddress = uint32(destAddress);
            obj.ServiceFlags = uint8(serviceFlags);
            obj.ServiceId = uint8(serviceId);
            obj.ObjectType = uint16(objectType);
            obj.ObjectId = uint32(objectId);
            obj.PropertyId = uint16(propertyId);
            obj.PropertyDataBytes = propertyDataBytes;
            
        end
        
        function str = formatCsvLine(obj, dataType)
            if nargin == 2
                parsedData = typecast(obj.PropertyDataBytes, dataType);
            else
                parsedData = [];
            end
            
            cells = [
                sprintf("%d", obj.SrcAddress),...
                sprintf("%d", obj.DestAddress),...
                obj.serviceFlagsHuman(),...
                obj.serviceIdHuman(),...
                obj.objectTypeHuman(),...
                sprintf("%d", obj.ObjectId),...
                sprintf("%d", obj.PropertyId),...
                "0x"+sprintf("%02x", obj.PropertyDataBytes),...
                sprintf("%.4g", parsedData)
            ];       
        str = strjoin(cells,';');
        end
        
        function str = toStr(obj, dataType)
            if nargin == 2
                parsedData = typecast(obj.PropertyDataBytes, dataType);
            else
                parsedData = [];
            end
            
            lines = [
                sprintf("%15s: %d - 0b%s", "FrameFlags", obj.FrameFlags, dec2bin(uint8(obj.FrameFlags), 8)),...
                sprintf("%15s: %d", "SrcAddress", obj.SrcAddress),...
                sprintf("%15s: %d", "DestAddress", obj.DestAddress),...
                sprintf("%15s: %d - %s", "ServiceFlags", obj.ServiceFlags, obj.serviceFlagsHuman),...
                sprintf("%15s: %d - %s", "ServiceId", obj.ServiceId, obj.serviceIdHuman),...
                sprintf("%15s: %d - %s", "ObjectType", obj.ObjectType, obj.objectTypeHuman),...
                sprintf("%15s: %d", "ObjectId", obj.ObjectId),...
                sprintf("%15s: %d", "PropertyId", obj.PropertyId),...
                sprintf("%15s: 0x%s - %.4g", "PropertyData", sprintf("%02x", obj.PropertyDataBytes), parsedData),...
            ];
            str = strjoin(lines, newline);
        end
        
        function str = serviceFlagsHuman(obj)
            switch obj.ServiceFlags
                case 0
                    str = "Request";
                case 2
                    str = "Response";
                case 3
                    str = "Error";
                otherwise
                    str = sprintf("%d", obj.ServiceFlags);
            end
        end
        
        function str = serviceIdHuman(obj)
            switch obj.ServiceId
                case 1
                    str = "Read";
                case 2
                    str = "Write";
                otherwise
                    str = sprintf("%d", obj.ServiceId);
            end
        end
        
        function str = objectTypeHuman(obj)
            switch obj.ObjectType
                case 1
                    str = "User Info";
                case 2
                    str = "Parameter";
                case 3
                    str = "Message";
                otherwise
                    str = sprintf("%d", obj.ObjectType);
            end
        end
        
        function bytes = toBytes(obj)
            dataBytes = [ 
                uint8(obj.ServiceFlags),...
                uint8(obj.ServiceId),...
                typecast(obj.ObjectType, "uint8"),...
                typecast(obj.ObjectId, "uint8"),...
                typecast(obj.PropertyId, "uint8"),...
                uint8(obj.PropertyDataBytes)
            ];
            
            headerBytes = [
                uint8(obj.FrameFlags),...
                typecast(obj.SrcAddress, "uint8"),...
                typecast(obj.DestAddress, "uint8"),...
                typecast(uint16(length(dataBytes)), "uint8")
            ];
        
            bytes = [uint8(170), headerBytes, SerialMessage.calculateChecksum(headerBytes),...
                dataBytes, SerialMessage.calculateChecksum(dataBytes)];
        end
    end
    methods(Access = protected)
       function propgrp = getPropertyGroups(~)
          proplist = {'Department','JobTitle','Name'};
          propgrp = matlab.mixin.util.PropertyGroup(proplist);
       end
    end
    methods(Static, Access=public)
        function obj = fromBytes(msgBytes)
            headerBytes = msgBytes(1:14);
            assert (headerBytes(1) == hex2dec("AA"))
            
            [frameFlags, srcAddress, destAddress] = SerialMessage.parseHeader(headerBytes);
            dataLen = SerialMessage.parseDataLength(headerBytes);
            
            dataBytes = msgBytes(15:14+dataLen);
            checksumBytes = msgBytes(14+dataLen+1:14+dataLen+2);
            
            assert(all(checksumBytes == SerialMessage.calculateChecksum(dataBytes)));
            
            [serviceFlags, serviceId] = SerialMessage.parseServiceInformation(dataBytes);
            [objectType, objectId, propertyId] = SerialMessage.parseObjectInformation(dataBytes);
            
            propertyDataBytes = dataBytes(11:end);
            
            obj = SerialMessage(frameFlags, srcAddress, destAddress, serviceFlags, serviceId, objectType, objectId, propertyId, propertyDataBytes);
        end
        
        function len = parseDataLength(headerBytes)
            len = typecast(headerBytes(11:12), "uint16");
        end
        
        function [frameFlags, srcAddress, destAddress] = parseHeader(headerBytes)
            frameFlags = headerBytes(2);
            srcAddress = typecast(headerBytes(3:6), "uint32");
            destAddress = typecast(headerBytes(7:10), "uint32");
        end
        
        function [serviceFlags, serviceId] = parseServiceInformation(dataBytes)
            serviceFlags = dataBytes(1);
            serviceId =  dataBytes(2);
        end
        
        function [objectType, objectId, propertyId] = parseObjectInformation(dataBytes)
            objectType = typecast(dataBytes(3:4), "uint16");
            objectId = typecast(dataBytes(5:8), "uint32");
            propertyId = typecast(dataBytes(9:10), "uint16");
        end
        
        function cs = calculateChecksum(dataBytes)
            a = uint32(hex2dec("FF"));
            b = uint32(0);
            for i = 1 : length(dataBytes)
                byte = uint32(dataBytes(i));
                a = mod(a + byte, hex2dec("100"));
                b = mod(a + b, hex2dec("100"));  
            end
            cs = uint8([a,b]);
        end
    end
end

