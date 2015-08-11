
#include <stdlib.h>
#include <math.h>

#include "../globaldefs.h"
#include "systemid_interface.h"

#include AIRCRAFT_UP1DIR

extern void get_system_id( double time, struct sensordata *sensorData_ptr, struct nav *navData_ptr, struct control *controlData_ptr, struct mission *missionData_ptr){
	unsigned short sysid_select = missionData_ptr -> sysid_select; 	// mode switching
	
	static double entry_time = 0;
	static int entry_time_latched = FALSE;
	static double local_time;
	
	static double f;
	
	
if(entry_time_latched == FALSE)
{
	entry_time = time;
	entry_time_latched = TRUE;
}
local_time = time - entry_time;
	
		
	//  apply to L3/R3 L4/R4    AT 27 M/S BASED ON DYNAMIC PRESSURE SCALING OF 23 M/S EXCITATION
	if(sysid_select == 1){	
		if (local_time < 18) 
		{
		f = 0.5 + (8.5-0.5)/(2.0*18.0) * (local_time);
			if (local_time < 11 ){
				controlData_ptr->pitch_cmd_excite = 3.6 * D2R * sin(2.0*3.14159265359 * f * (local_time));
			}
			else{
				controlData_ptr->pitch_cmd_excite = 0.75 * D2R * sin(2.0*3.14159265359 * f * (local_time));
			}
		controlData_ptr->l3    += controlData_ptr->pitch_cmd_excite;
		controlData_ptr->r3    += controlData_ptr->pitch_cmd_excite;	
		}
		else if ( (local_time > 20)&& (local_time < 38) ) 
		{
		f = 0.5 + (8.5-0.5)/(2.0*18.0) * (local_time-20.0);
		if ((local_time-20.0) < 11 ){
			controlData_ptr->pitch_cmd_excite = 3.6 * D2R * sin(2.0*3.14159265359 * f * (local_time-20.0));	
			}
		else{
			controlData_ptr->pitch_cmd_excite = 0.75 * D2R * sin(2.0*3.14159265359 * f * (local_time-20.0));
		}			
		controlData_ptr->l4     +=  controlData_ptr->pitch_cmd_excite;
		controlData_ptr->r4   	+=  controlData_ptr->pitch_cmd_excite;
		}
			
		
	}
	//  apply to L3/R3 L4/R4 AT 23 M/S BASED ON ENERGY CONTENT OF 3-2-1-1 SIGNAL IN PREVIOUS FLIGHT TESTS
	else if(sysid_select == 0){
		if (local_time < 18 )
		{
		f = 0.5 + (8.5-0.5)/(2.0*18.0) * (local_time);
			if (local_time < 11 ){
				controlData_ptr->pitch_cmd_excite = 5.0 * D2R * sin(2.0*3.14159265359 * f * (local_time));
			}
			else{
				controlData_ptr->pitch_cmd_excite = 1.0 * D2R * sin(2.0*3.14159265359 * f * (local_time));
			}
			
		controlData_ptr->l3     +=  controlData_ptr->pitch_cmd_excite;
		controlData_ptr->r3   	+=  controlData_ptr->pitch_cmd_excite;	
		}
		else if ( (local_time > 20)&& (local_time < 38) )
		{
		f = 0.5 + (8.5-0.5)/(2.0*18.0) * (local_time-20.0);
			if ((local_time-20.0) < 12 ){		
				controlData_ptr->pitch_cmd_excite = 5.0 * D2R * sin(2.0*3.14159265359 * f * (local_time-20.0));
			}
			else{
				controlData_ptr->pitch_cmd_excite = 1.0 * D2R * sin(2.0*3.14159265359 * f * (local_time-20.0));	
			}
		controlData_ptr->l4     += 	controlData_ptr->pitch_cmd_excite;
		controlData_ptr->r4   	+= 	controlData_ptr->pitch_cmd_excite;
		}			
	}
	// 	Pitch Command Doublets
	else if(sysid_select == 2){
	}
}

