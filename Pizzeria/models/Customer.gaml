/**
* Name: Customer
* Define customer species 
* Author: root
* Tags: 
*/


model Customer

import "Pizzeria.gaml"

/* Insert your model definition here */

species Customer skills: [moving] {
	point target;
    float patience <- 80.0;
    float satisfaction <- 100.0;
    float waiting_time <- 0.0;
    string state;
    float decision_timer <- 0.0;
    bool wants_to_enter <- false;
    bool direction_left <- false;
    bool is_in <- false;
    float radius <- 2.0;
    
    init {
	    state <- "going_to_door";
	    target <- door_location;
	}
	
	reflex move_to_door when: state = "going_to_door" and every(3#cycle){
	    if target != nil {
	        do goto(speed: 2.0, target: target);
	
	        if distance_to(location, target) < 2.0 {
	            state <- "arrived_at_door";
	            decision_timer <- 0.0;
	        }
	    }
	}
	
	reflex wait_at_door when: state = "arrived_at_door" and every(2#cycle){
	    decision_timer <- decision_timer + 1.0;
	
	    if decision_timer > rnd(3.0, 4.0) {
	        state <- "deciding";
	    }
	}
	
	reflex enter when: state = "entering" and every(3#cycle) {
	    do goto(speed: 2.0, target: target);
	    is_in <- true;
		
	    if distance_to(location, target) < 2.0 {
	        state <- "waiting"; // ou autre logique interne
	    }
	}
	
	reflex decide when: state = "deciding" {

	    if flip(0.6) and length(waiting_queue) < 8 {
	        state <- "entering";
	        target <- inside_point;
	    } else {
	        state <- "leaving";
	        target <- location + {rnd(-20,20), rnd(-20,20)};
	    }
	}

    reflex wait when: state = "waiting" and every(2#cycle){
        waiting_time <- waiting_time + 1.0;
        if (waiting_time > patience) {
            state <- "leaving";
        }
    }
    
    reflex leave when: state = "leaving" and every(3#cycle){
    	if is_in {
    		target <- entrance_door;
    		
    		if distance_to(location, target) < 2.0 {
		        is_in <- false;
		    }
		    
		    if target != nil {
		        do goto(speed: 3.0, target: target);
		    }
    	} else {
		    if direction_left {
	        	target <- left_sidewalk;
	        } else {
	        	target <- right_sidewalk;
	        }
	        if target != nil {
		        do goto(speed: 3.0, target: target);
		        
		        if distance_to(location, target) < 2.0 {
			        do die; 
		   		}
	    	}
	    }
	}
    
    aspect base {
	    rgb col <- #red;
	    if (state = "waiting") { col <- #orange; }
	    else if (state = "eating") { col <- #limegreen; }
	
	    draw circle(2.0) color: col border: #white;
	}
}