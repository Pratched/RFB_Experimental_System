addpath('C:\Users\ESS\Desktop\LastQuellAnsteuerung')  
instrreset;
delete(timerfindall)
clc;
clear all;


sc = DEQuelleAnsteuerung('DE60100.cnf', 4);
lc = HHLastAnsteuerung('HH4812.cnf', 5);
rfbc = RFBConnection("141.76.14.122", 502, 1, 10);
emulator = WREmulator("COM3", "COM2");

sc.open();
lc.open();
fopen(emulator);

exp = ExperimentalSystem(rfbc, lc, sc, emulator, false);

exp.runControlRoutine();
exp.runExperiment([8,8,0,0,8,8], 5);