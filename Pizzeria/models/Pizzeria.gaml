model Pizzeria

import "Cook.gaml"
import "Counter.gaml"
import "Machine.gaml"
import "Customer.gaml"
import "Table.gaml"

global {
    // ── Dimensions ─────────────────────────────────────────────────────────
    int width  <- 200;
    int height <- 200;
    geometry shape       <- rectangle(width, height);
    geometry kitchen     <- rectangle(width, 90)  at_location {width / 2, height - 40};
    geometry entrance    <- rectangle(40, 10)     at_location {width - 50, 25};
    geometry sidewalk    <- rectangle(width, 50)  at_location {width / 2, 0};
    geometry dining_area <- rectangle(110, 80)    at_location {70, 70};
	geometry waiting_area <- rectangle(20, 60) at_location {185, 70};

    // ── Points de navigation ───────────────────────────────────────────────
    point door_location  <- {entrance.location.x, entrance.location.y - 10};
    point inside_point   <- {entrance.location.x, entrance.location.y + 40};
    point left_sidewalk  <- {20, 10};
    point right_sidewalk <- {width - 20, 10};
    point takeaway_waiting_area <- {width / 2, 40};

    // ── Paramètres clients ─────────────────────────────────────────────────
    int nb_customers   <- 10;
    int nb_tables <- 10;
    int queue_capacity <- 8;
    float lambda_arrival <- 6.0; // Mean arrivals per check
    int spawn_every    <- 5;
    list<Customer> waiting_queue <- [];
    
    // ── Paramètres cuisine ─────────────────────────────────────────────────
    int nb_cooks    <- 4;
    int nb_machines <- 4;
    int nb_counters <- 4;
    int static_counter_id <- 0;

    float cook_speed     <- 2.0;
    int min_task_time    <- 5;
    int max_task_time    <- 20;
    int order_wait_time  <- 15;

    // ── Menu (prix -> tasks/unité = round(prix/10)) ─────────────────────────
    map<string, int> menu <- [
        "pizza_margherita" :: 15,
        "pizza_pepperoni"  :: 18,
        "salad"            :: 10,
        "drink"            :: 5
    ];

    list<Machine> work_stations    <- [];
    list<Counter> counter_stations <- [];
    
    // ── Performance Metrics ────────────────────────────────────────────────
    float restaurant_ca     <- 0.0;
    int served_customers    <- 0;
    int unsatisfied_customers <- 0;
    float total_satisfaction <- 0.0;
    float avg_satisfaction    <- 100.0;
    float total_wait_time     <- 0.0;
    float avg_wait_time     <- 0.0;
    
    list<float> revenue_history <- [];
    map<string, int> item_usage <- []; // Tracks total units sold per item
    float last_revenue_checkpoint <- 0.0;
    float revenue_velocity_pct <- 0.0;

    // Updates global KPIs based on customer outcomes
    action update_metrics(int sat, float wait, bool success) {
        if (success) { served_customers <- served_customers + 1; } 
        else { unsatisfied_customers <- unsatisfied_customers + 1; restaurant_ca <- restaurant_ca - rnd(10, 30); }
        
        total_satisfaction <- total_satisfaction + sat;
        total_wait_time <- total_wait_time + wait;
        
        // The average now includes unsatisfied customers (sat=0) to reflect overall performance
        if (served_customers + unsatisfied_customers > 0) {
            avg_satisfaction <- total_satisfaction / (served_customers + unsatisfied_customers);
            avg_wait_time    <- total_wait_time / (served_customers + unsatisfied_customers);
        }
    }
    	
	init {
		create Table number: nb_tables {
		    location <- any_location_in(dining_area);
		    max_capacity   <- rnd(1, 4);
		    occupied_seats <- 0;
		 }

        // Initialize item usage tracking
        loop k over: menu.keys {
            item_usage[k] <- 0;
        }
	
		create Customer number: nb_customers {
			if flip(0.5) {
				location <- {left_sidewalk.x, rnd(left_sidewalk.y - 10, left_sidewalk.y + 10)};
				direction_left <- false;
			} else {
				location <- {right_sidewalk.x, rnd(right_sidewalk.y - 10, right_sidewalk.y + 10)};
				direction_left <- true;
			}
			state  <- "going_to_door";
			target <- door_location + {rnd(-2, 2), rnd(-2, 2)};
		}

        create Machine number: nb_machines {
            location <- any_location_in(kitchen);
        }

		create Counter number: nb_counters;

		create Cook number: nb_cooks {
			location <- any_location_in(kitchen);
		}

		work_stations    <- list(Machine);
		counter_stations <- list(Counter);
	}
	
    // ── Dynamic Population Management ──
    // These reflexes allow changing agent numbers in real-time via the UI parameters.
    
    reflex manage_entities {
        // Manage Tables
        if length(Table) < nb_tables { create Table number: (nb_tables - length(Table)) { location <- any_location_in(dining_area); max_capacity <- rnd(1,4); } }
        else if length(Table) > nb_tables { 
            list<Table> candidates <- Table where (each.occupied_seats = 0);
            if !empty(candidates) { ask (min([length(Table) - nb_tables, length(candidates)])) among candidates { do die; } }
        }
        
        // Manage Cooks (Staffing)
        if length(Cook) < nb_cooks { create Cook number: (nb_cooks - length(Cook)) { location <- any_location_in(kitchen); } }
        else if length(Cook) > nb_cooks {
            list<Cook> idle_staff <- Cook where (each.state = "idle");
            if !empty(idle_staff) { ask (min([length(Cook) - nb_cooks, length(idle_staff)])) among idle_staff { do die; } }
        }

        // Manage Machines (Kitchen Capacity)
        if length(Machine) < nb_machines { create Machine number: (nb_machines - length(Machine)) { location <- any_location_in(kitchen); } work_stations <- list(Machine); }
        else if length(Machine) > nb_machines {
            list<Machine> free_m <- Machine where (!each.is_occupied);
            if !empty(free_m) { ask (min([length(Machine) - nb_machines, length(free_m)])) among free_m { do die; } work_stations <- list(Machine); }
        }
        
        // Manage Counters
        if length(Counter) < nb_counters { create Counter number: (nb_counters - length(Counter)); counter_stations <- list(Counter); }
        else if length(Counter) > nb_counters {
            list<Counter> free_c <- Counter where (!each.is_occupied);
            if !empty(free_c) { ask (min([length(Counter) - nb_counters, length(free_c)])) among free_c { do die; } counter_stations <- list(Counter); }
        }
    }

    // ── Financial Tracking ──
    reflex track_revenue_step when: every(1000 #cycle) {
        // Calculate what % of total CA was made in the last 100 steps
        float delta <- restaurant_ca - last_revenue_checkpoint;
        revenue_velocity_pct <- (restaurant_ca > 0) ? (delta / restaurant_ca) * 100 : 0.0;
        last_revenue_checkpoint <- restaurant_ca;
        
        revenue_history << restaurant_ca;
        if (length(revenue_history) > 10) { remove from: revenue_history index: 0; }
    }

    // ── Customer Spawn Logic ──
    // Uses a Poisson distribution to model realistic arrival patterns.
    reflex spawn_customers when: every(spawn_every #cycle) {
        // Using Poisson distribution to determine number of arrivals
        int arrivals <- poisson(lambda_arrival);
        if arrivals > 0 and (length(Customer) < nb_customers) {
            create Customer number: min([arrivals, nb_customers - length(Customer)]) {
                if flip(0.5) {
                    location       <- {left_sidewalk.x,  rnd(left_sidewalk.y  - 10, left_sidewalk.y  + 10)};
                    direction_left <- false;
                } else {
                    location       <- {right_sidewalk.x, rnd(right_sidewalk.y - 10, right_sidewalk.y + 10)};
                    direction_left <- true;
                }
            }
        }
    }
}