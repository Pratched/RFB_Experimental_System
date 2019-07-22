addpath('C:\Users\ESS\Desktop\LastQuellAnsteuerung')  
instrreset;

sc = DEQuelleAnsteuerung('DE60100.cnf', 4);
lc = HHLastAnsteuerung('HH4812.cnf', 5);
rfbc = RFBConnection("141.76.14.122", 502, 1, 10);

sc.open();
lc.open();


exp = ExperimentalSystem(rfbc, lc, sc);

exp.runControlRoutine();
pause(1);

exp.runExperiment([-1,0,-1,0], 5);