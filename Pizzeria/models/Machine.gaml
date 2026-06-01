/**
* Name: Machine
* Machine species 
* Author: root
* Tags: 
*/


model Machine

import "Pizzeria.gaml"

species Machine {
    geometry shape <- rectangle(8, 8);
    bool is_occupied <- false;
    Cook current_cook <- nil;
    //int work_start_time <- 0;

    init {
    	//location <- any_location_in(kitchen);
        //work_stations +<- shape;
    }

    aspect base {
        draw shape color: #green border: #black;
        if is_occupied {
            draw shape at: {location.x, location.y} font: font("Arial", 8, #plain) color: #darkred border: #black;
        } else {
            draw shape at: {location.x, location.y} font: font("Arial", 8, #plain) color: #green border: #black;
        }
    }
}