clear; close all; clc;

% The second argument to the VISA function is the resource string for your
% instrument
visaObj = visa('agilent','TCPIP0::192.168.1.23::inst0::INSTR');
% Set the buffer size
visaObj.InputBufferSize = 20000000;
% Set the timeout value
visaObj.Timeout = 10;
% Set the Byte order
visaObj.ByteOrder = 'littleEndian';
% Open the connection
fopen(visaObj);
%% Instrument control and data retreival
% Now control the instrument using SCPI commands. refer to the instrument
% programming manual for your instrument for the correct SCPI commands for
% your instrument.
% Reset the instrument and autoscale and stop
%fprintf(visaObj,'*RST; :AUTOSCALE'); 
fprintf(visaObj,':STOP');
% Specify data from Channel 1
fprintf(visaObj,':WAVEFORM:SOURCE CHAN1'); 
% Set timebase to main
fprintf(visaObj,':TIMEBASE:MODE MAIN');
% Set up acquisition type and count. 
fprintf(visaObj,':ACQUIRE:TYPE NORMAL');
fprintf(visaObj,':ACQUIRE:COUNT 1');
% Specify 5000 points at a time by :WAV:DATA?
fprintf(visaObj,':WAV:POINTS:MODE RAW');
fprintf(visaObj,':WAV:POINTS 10000');
% Now tell the instrument to digitize channel1
fprintf(visaObj,':DIGITIZE CHAN1');
% Wait till complete
operationComplete = str2double(query(visaObj,'*OPC?'));
while ~operationComplete
    operationComplete = str2double(query(visaObj,'*OPC?'));
end
% Get the data back as a WORD (i.e., INT16), other options are ASCII and BYTE
fprintf(visaObj,':WAVEFORM:FORMAT WORD');
% Set the byte order on the instrument as well
fprintf(visaObj,':WAVEFORM:BYTEORDER LSBFirst');
% Get the preamble block
preambleBlock = query(visaObj,':WAVEFORM:PREAMBLE?');
% The preamble block contains all of the current WAVEFORM settings.  
% It is returned in the form <preamble_block><NL> where <preamble_block> is:
%    FORMAT        : int16 - 0 = BYTE, 1 = WORD, 2 = ASCII.
%    TYPE          : int16 - 0 = NORMAL, 1 = PEAK DETECT, 2 = AVERAGE
%    POINTS        : int32 - number of data points transferred.
%    COUNT         : int32 - 1 and is always 1.
%    XINCREMENT    : float64 - time difference between data points.
%    XORIGIN       : float64 - always the first data point in memory.
%    XREFERENCE    : int32 - specifies the data point associated with
%                            x-origin.
%    YINCREMENT    : float32 - voltage diff between data points.
%    YORIGIN       : float32 - value is the voltage at center screen.
%    YREFERENCE    : int32 - specifies the data point where y-origin
%                            occurs.
% Now send commmand to read data
fprintf(visaObj,':WAV:DATA?');
% read back the BINBLOCK with the data in specified format and store it in
% the waveform structure. FREAD removes the extra terminator in the buffer
waveform.RawData = binblockread(visaObj,'int16'); fread(visaObj,1);
% Read back the error queue on the instrument
% instrumentError = query(visaObj,':SYSTEM:ERR?');
% while ~isequal(instrumentError,['+0,"No error"' char(10)])
%     disp(['Instrument Error: ' instrumentError]);
%     instrumentError = query(visaObj,':SYSTEM:ERR?');
% end
% Close the VISA connection.
fclose(visaObj);
delete(visaObj);
%% Data processing: Post process the data retreived from the scope
% Extract the X, Y data and plot it 
% Maximum value storable in a INT16
maxVal = 2^16; 
%  split the preambleBlock into individual pieces of info
preambleBlock = regexp(preambleBlock,',','split');
% store all this information into a waveform structure for later use
waveform.Format = str2double(preambleBlock{1});     % This should be 1, since we're specifying INT16 output
waveform.Type = str2double(preambleBlock{2});
waveform.Points = str2double(preambleBlock{3});
waveform.Count = str2double(preambleBlock{4});      % This is always 1
waveform.XIncrement = str2double(preambleBlock{5}); % in seconds
waveform.XOrigin = str2double(preambleBlock{6});    % in seconds
waveform.XReference = str2double(preambleBlock{7});
waveform.YIncrement = str2double(preambleBlock{8}); % V
waveform.YOrigin = str2double(preambleBlock{9});
waveform.YReference = str2double(preambleBlock{10});
waveform.VoltsPerDiv = (maxVal * waveform.YIncrement / 8);      % V
waveform.Offset = ((maxVal/2 - waveform.YReference) * waveform.YIncrement + waveform.YOrigin);         % V
waveform.SecPerDiv = waveform.Points * waveform.XIncrement/10 ; % seconds
waveform.Delay = ((waveform.Points/2 - waveform.XReference) * waveform.XIncrement + waveform.XOrigin); % seconds
% Generate X & Y Data
waveform.XData = (waveform.XIncrement.*(1:length(waveform.RawData))) - waveform.XIncrement;
waveform.YData = (waveform.YIncrement.*(waveform.RawData - waveform.YReference)) + waveform.YOrigin; 
% Plot it
figure(1)
plot(waveform.XData,waveform.YData);
set(gca,'XTick',(min(waveform.XData):waveform.SecPerDiv:max(waveform.XData)))
xlabel('Time (s)');
ylabel('Volts (V)');
title('Oscilloscope Data');