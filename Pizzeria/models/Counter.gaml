/**
* Name: Counter
* Based on the internal empty template. 
* Author: root
* Tags: 
*/


model Counter

import "Pizzeria.gaml"

species Counter {
    geometry shape <- rectangle(6, 6);
    bool is_occupied <- false;
    Cook current_cook <- nil;
    
    init {
    	static_counter_id <- static_counter_id + 1;    	
        location <- {width - 50 + (static_counter_id * 8.0), dining_area.location.y + 45};
        counter_stations +<- shape;
    }
    
    aspect base {
        draw shape color: #grey border: #black;
        draw "Counter" font: font("Arial", 5, #plain) color: #white;
    }
}