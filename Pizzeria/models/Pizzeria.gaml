model Pizzeria

global {
    int width <- 200;
    int height <- 200;
    int nb_customers <- 10;
    
    point entrance_door <- {width - 50 , 25};  
    point door_location <- {entrance_door.x, entrance_door.y - 10};
    point inside_point <- {entrance_door.x, entrance_door.y + 40};
    point left_sidewalk <- {20, 10};
    point right_sidewalk <- {width-20, 10};
    geometry shape <- rectangle(width, height);
    
    list<Customer> waiting_queue <- [];
    int queue_capacity <- 8;
    int spawn_every <- 5; 

    init {    	
        create Table number: 5 {
            location <- {rnd(width), rnd(height)};
            state <- "free";
        }

        create Customer number: nb_customers {
            patience <- rnd(50.0, 100.0);
            satisfaction <- 100.0;
            if flip(0.5) {
		        location <- {left_sidewalk.x, rnd(left_sidewalk.y-10,left_sidewalk.y+10)};
		        direction_left <- false;
		    } else {
		        location <- {right_sidewalk.x, rnd(right_sidewalk.y-10,right_sidewalk.y+10)};
		        direction_left <- true;
		    }
		}

        create Cook number: 2 {
            location <- {rnd(width), rnd(height)};
        }
    }
    
    reflex manage_queue when: every(5#cycle){
        waiting_queue <- waiting_queue where (each.state = "in_queue" or each.state = "ordering");    
    }
    
    reflex spawn_customers when: every(spawn_every#cycle){
        if length(Customer) < nb_customers {
            create Customer number: 1 {
                if flip(0.5) {
			        location <- {left_sidewalk.x, rnd(left_sidewalk.y-10,left_sidewalk.y+10)};
			        direction_left <- false;
			    } else {
			        location <- {right_sidewalk.x, rnd(right_sidewalk.y-10,right_sidewalk.y+10)};
			        direction_left <- true;
			    }

                state <- "going_to_door";
                target <- door_location + {rnd(-2, 2), rnd(-2, 2)};
            }
        }
    }
}

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

species Cook skills: [moving] {
    string state <- "idle";
    int workload <- 0;

    reflex move {
        do wander speed: 1.0 bounds: world.shape;
    }

    aspect base {
        draw circle(2.5) color: #firebrick border: #white;
        draw "Cook" font: font("Arial", 7, #plain) at: {location.x, location.y - 3} color: #black;
    }
}

species Machine {
    float cost <- 100.0;
    string state <- "idle";
    float failure_chance <- 0.01;

    aspect base {
        draw square(4) color: (state = "broken") ? #red : #gray border: #darkgray;
    }
}

species Table {
    int capacity <- 4;
    int max_capacity <- 4;
    string state <- "free";

    aspect base {
        draw square(5) color: (state = "free") ? #mediumseagreen : #tomato border: #white;
        draw state font: font("Arial", 7, #plain) at: {location.x, location.y - 3} color: #black;
    }
}

experiment "Pizzeria_GUI" type: gui {

    parameter "Number of customers" var: nb_customers min: 1 max: 30 init: 10;

    output {
        display main type: 2d background: #whitesmoke {

            graphics "background" {
                draw rectangle(width, height) at: {width/2, height/2}
                    color: #blue border: #yellow;
                    
                // Sidewalk
                draw rectangle(width, 50) at: {width/2,0} color: #red border: #gray;
                // Entrance
                draw rectangle(40, 10) at: entrance_door color: #green;
                // Kitchen
                draw rectangle(width, 90) at: {width/2, height-40} color: #purple;
            }

            species Table aspect: base;
            species Machine aspect: base;
            species Cook aspect: base;
            species Customer aspect: base;
        }
    }
}