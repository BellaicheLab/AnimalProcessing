function frame = GiveMeTheFrameOf(animal,time)

MAPcall = true;
eval(['SAP_info_' animal]);

frame = time2frame(time,timeRef,frameRef,dt);