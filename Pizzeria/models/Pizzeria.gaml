model Pizzeria

import "Cook.gaml"
import "Counter.gaml"
import "Machine.gaml"
import "Customer.gaml"
import "Table.gaml"

global {
	int width <- 200;
	int height <- 200;
	int nb_customers <- 10;
	geometry shape <- rectangle(width, height);
	geometry kitchen <- rectangle(width, 90) at_location {width / 2, height - 40};
	geometry entrance <- rectangle(40, 10) at_location {width - 50, 25};
	geometry sidewalk <- rectangle(width, 50) at_location {width / 2, 0};
	geometry dining_area <- rectangle(110, 80) at_location {70, 70};
	
	point door_location <- {entrance.location.x, entrance.location.y - 10};
	point inside_point <- {entrance.location.x, entrance.location.y + 40};
	point left_sidewalk <- {20, 10};
	point right_sidewalk <- {width - 20, 10};
	list<Customer> waiting_queue <- [];
	int queue_capacity <- 8;
	int spawn_every <- 5;
	float restaurant_rating <- 100.0;
	int served_customers <- 0;
	map<string, int> menu <- ["pizza_margherita"::15, "pizza_pepperoni"::18, "salad"::10, "drink"::5, "menu_deluxe"::25];
	list<map> pending_orders <- [];
	point takeaway_waiting_area <- {width / 2, 40};

	/* Added */
	list<geometry> work_stations <- []; 
    list<geometry> counter_stations <- [];
	int min_work_duration <- 10;
	
	init {
		create Table number: 8 {
	
		    location <- any_location_in(dining_area);
		
		    max_capacity <- rnd(1,4);
		
		    occupied_seats <- 0;
		 }
	
		create Customer number: nb_customers {
			if flip(0.5) {
				location <- {left_sidewalk.x, rnd(left_sidewalk.y - 10, left_sidewalk.y + 10)};
				direction_left <- false;
			} else {
				location <- {right_sidewalk.x, rnd(right_sidewalk.y - 10, right_sidewalk.y + 10)};
				direction_left <- true;
			}

		}
		
		create Machine number: 4 {
			location <- any_location_in(kitchen);
		}
		
		create Counter number: 2 {
            location <- {width - 60, height - 45}; // Exemple : proche de l'entrée/kitchen
        }

		create Cook number: 2 {
			location <- {rnd(width), rnd(height - 50, height)};
		}

		counter_stations +<- (Counter collect each.shape);
	}

	reflex manage_queue when: every(5 #cycle) {
		waiting_queue <- waiting_queue where (each.state = "in_queue" or each.state = "ordering");
	}

	reflex spawn_customers when: every(spawn_every #cycle) {
		if length(Customer) < nb_customers {
			create Customer number: 1 {
				if flip(0.5) {
					location <- {left_sidewalk.x, rnd(left_sidewalk.y - 10, left_sidewalk.y + 10)};
					direction_left <- false;
				} else {
					location <- {right_sidewalk.x, rnd(right_sidewalk.y - 10, right_sidewalk.y + 10)};
					direction_left <- true;
				}

				state <- "going_to_door";
				target <- door_location + {rnd(-2, 2), rnd(-2, 2)};
			}

		}

	}

}