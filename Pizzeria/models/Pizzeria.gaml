model Pizzeria

import "Cook.gaml"
import "Customer.gaml"
import "Table.gaml"

global {
    int width <- 200;
    int height <- 200;
    int nb_customers <- 10;
    
    geometry shape <- rectangle(width, height);
    point entrance_door <- {width - 50 , 25};  
    point door_location <- {entrance_door.x, entrance_door.y - 10};
    point inside_point <- {entrance_door.x, entrance_door.y + 40};
    point left_sidewalk <- {20, 10};
    point right_sidewalk <- {width-20, 10};
    
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
            location <- {rnd(width ), rnd(height - 50, height)};
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