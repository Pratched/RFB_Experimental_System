classdef States
    %STATE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(Constant)
        STANDBY = 00000; %Connections are open but system does nothing
        STARTUP = 11111; %Connections closes and system does nothing
        RUNNING = 22222; %RFBC Pumps fluid without any load
        SHUTDOWN = 33333; %Experiment is running
        STOPPED = 44444;
    end
end

