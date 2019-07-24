classdef States
    %STATE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(Constant)
        STANDBY = 00000; 
        STARTUP = 11111; 
        RUNNING = 22222; 
        SHUTDOWN = 33333; 
        STOPPED = 44444;
    end
end

