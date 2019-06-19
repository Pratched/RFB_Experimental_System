
rfbc = RFBConnection("141.76.14.122",502, 1, 1);
rfbc.getAlarms(@callbackResp);
%rfbc.requestAlarms( @callbackResp);
%rfbc.requestOpenCircuitVoltage(@callbackResp);
pause(1.5);
delete(rfbc);

function callbackResp(value)
    disp("received:")
    disp(value)
end
