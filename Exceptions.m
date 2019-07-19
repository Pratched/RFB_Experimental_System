classdef Exceptions
    %EXCEPTIONS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(Constant)
        RESPONSE_NOT_DEFINED_EXCEPTION = "Emulation:ResponseNotDefined";
        EMULATOR_VALUE_EXCEPTION = "Emulation:InvalidValue";
        
        VALUE_TIMEOUT_EXCEPTION = "Measurement:ValueTimeout";
        
        VALUE_OOB_EXCEPTION = "Experiment:ValueOutOfBounds";
    end
end

