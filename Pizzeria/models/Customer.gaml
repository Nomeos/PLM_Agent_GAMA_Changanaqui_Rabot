/**
 * Name: Customer
 * Description: Defines the behavior of customers inside the pizzeria
 * Author: Mathieu Rabot et Yoann Changanaqui
 */

model Customer

import "Pizzeria.gaml"

species Customer skills: [moving] {

    /****************************************
     *           CUSTOMER DATA
     ****************************************/

    // --- Identity ---
    string customer_type;
    int max_food_wait;
	float annoyance_factor;
	float effective_food_wait;

    // --- Movement / Position ---
    point target;
    bool direction_left <- false;
    bool is_in <- false;

    // --- Needs / Satisfaction ---
    int patience;
    int satisfaction;
    int hunger;

    // --- Timers ---
    float decision_timer <- 0.0;
    float waiting_for_food_time <- 0.0;
	float eating_time <- 0.0;
	float queue_wait_time <- 0.0;

    // --- State Machine ---
    string state;

    // --- Order Information ---
    string chosen_meal <- nil;
    bool takeaway <- false;

    // --- Table Management ---
    Table assigned_table <- nil;
    point seat_position <- nil;
    
    // --- Counter Management ---
    Counter assigned_counter <- nil;

    /****************************************
     *              INIT
     ****************************************/

    init {

	    state <- "going_to_door";
	    target <- door_location;
	
	    customer_type <- one_of([
	        "regular",
	        "vip",
	        "impatient",
	        "foodie"
	    ]);
	
	    switch customer_type {

            match "regular" {
                patience <- rnd(80,120);
                max_food_wait <- rnd(60,90);
                annoyance_factor <- 1.0;
                hunger <- rnd(40,90);
                satisfaction <- 80;
            }

            match "vip" {
                patience <- rnd(120,180);
                max_food_wait <- rnd(90,140);
                annoyance_factor <- 1.5;
                satisfaction <- 120;
                hunger <- rnd(50,100);
            }

            match "impatient" {
                patience <- rnd(40,70);
                max_food_wait <- rnd(25,45);
                annoyance_factor <- 2.5;
                satisfaction <- 70;
                hunger <- rnd(70,100);
            }

            match "foodie" {
                patience <- rnd(100,160);
                max_food_wait <- rnd(70,120);
                annoyance_factor <- 2.0;
                satisfaction <- 90;
                hunger <- rnd(80,100);
            }
        }
        // La patience modifie réellement le temps acceptable d'attente
		effective_food_wait <- max_food_wait * (patience / 100.0);
	}

    /****************************************
     *        MOVE TO RESTAURANT
     ****************************************/

    // Customer walks toward the entrance
    reflex move_to_door
    when: state = "going_to_door" {

        if target != nil {

            do goto(speed: 2.0, target: target);

            // Once near the door, start deciding
            if distance_to(location, target) < 2.0 {
                state <- "arrived_at_door";
                decision_timer <- 0.0;
            }
        }
    }

    // Customer waits a bit before making a decision
    reflex wait_at_door
    when: state = "arrived_at_door" {

        decision_timer <- decision_timer + 1.0;

        if decision_timer > rnd(3.0, 4.0) {
            state <- "deciding";
        }
    }

    /****************************************
     *          ENTER OR LEAVE
     ****************************************/

    // Decide whether to enter the restaurant
    reflex decide
    when: state = "deciding" {

        // 60% chance to enter if queue is not too large
        //if flip(hunger) and length(waiting_queue) < 8 {

        // Probability based on Poisson arrival rate vs Hunger
        // P(k>0) = 1 - exp(-lambda)
        float arrival_prob <- 1 - exp(-lambda_arrival);
        
        if flip(arrival_prob * (hunger/100)) and length(waiting_queue) < 8 {
            state <- "entering";
            target <- inside_point;
        } else {
            // Otherwise leave immediately
            state <- "leaving";
            target <- location + {rnd(-20,20), rnd(-20,20)};
        }
    }

    // Transition from sidewalk to the pizzeria
    reflex enter
    when: state = "entering" {

        do goto(speed: 2.0, target: target);

        is_in <- true;

        if distance_to(location, target) < 2.0 {
            state <- "seeking_counter";
        }
    }
    
        /****************************************
     *        COUNTER — ORDERING
     ****************************************/

    // Cherche un comptoir libre ou attend
    reflex seek_counter
    when: state = "seeking_counter" {

        list<Counter> free_counters <- counter_stations where (each.is_occupied = false);

        if length(free_counters) > 0 {

            // Prend le premier comptoir libre
            assigned_counter <- free_counters[0];
            assigned_counter.is_occupied <- true;
            target <- assigned_counter.location;
            state <- "going_to_counter";

        } else {

            // Aucun comptoir libre : attendre au point d'attente
            state <- "waiting_for_counter";
            target <- any_location_in(waiting_area);
            queue_wait_time <- 0.0;
        }
    }

    // Attendre qu'un comptoir se libère
    reflex wait_for_counter
    when: state = "waiting_for_counter" and every(1#cycle) {

        do goto(speed: 1.0, target: target);

        // Try to grab a counter
        list<Counter> free_counters <- counter_stations where (!each.is_occupied);
        if length(free_counters) > 0 {
            assigned_counter <- one_of(free_counters);
            assigned_counter.is_occupied <- true;
            target <- assigned_counter.location;
            state <- "going_to_counter";
        }
    }

    // Global patience monitor: if the customer waits too long in any service state, they leave
    reflex check_patience when: (state = "ordering" or state = "waiting_for_counter" or state = "waiting_food") {
        queue_wait_time <- queue_wait_time + 1;
        if (queue_wait_time > effective_food_wait) {
            if (assigned_counter != nil) { assigned_counter.is_occupied <- false; assigned_counter <- nil; }
            if (assigned_table != nil) { assigned_table.occupied_seats <- assigned_table.occupied_seats - 1; assigned_table <- nil; }
            
            satisfaction <- 0;
            ask world { do update_metrics(myself.satisfaction, myself.queue_wait_time, false); }
            state <- "leaving_frustrated";
        }
    }

    // Se déplacer vers le comptoir
    reflex go_to_counter
    when: state = "going_to_counter" {

        do goto(speed: 2.0, target: target);

        if distance_to(location, target) < 2.0 {
            state <- "ordering";
        }
    }

    // The ordering process is now handled by the Cook via an 'ask' block.
    // The customer stays in 'ordering' state (passive wait) until the Cook picks them up.

    /****************************************
     *       DINE-IN OR TAKEAWAY
     ****************************************/

    // Decide if customer eats inside or takeaway
    reflex choose_eat_mode
    when: state = "choose_mode" {
        // Safe release of counter
        if (assigned_counter != nil) { assigned_counter.is_occupied <- false; assigned_counter <- nil; }
        
        // Hungry customers are more likely to stay
        float dine_prob <- hunger / 100;

        takeaway <- not flip(dine_prob);

        // --- DINE IN ---
        if not takeaway {

			list<Table> candidates <- Table where (each.has_free_seat());
			Table free_table <- one_of(candidates);
	

			// Table found
			if free_table != nil {
				assigned_table <- free_table;
				
				// Capture the current count as the index BEFORE incrementing.
				// If 0 seats are occupied, we want index 0. This avoids the "-1" crash.
				int seat_idx <- assigned_table.occupied_seats;

				ask assigned_table {
					do reserve_seat;
				}
				
				// Defensive check: ensure the index is valid for the table's seat list
				if (seat_idx >= 0 and seat_idx < length(assigned_table.seat_positions)) {
					seat_position <- assigned_table.location + assigned_table.seat_positions[seat_idx];
					state <- "going_to_table";
				} else {
					// Safety fallback: if the table reports a seat but the list is empty/full
					takeaway <- true;
					state <- "waiting_food";
				}
			} else {

                // No table available -> forced takeaway
                takeaway <- true;

                // Customer is disappointed
                do change_satisfaction(
                	-(1 * annoyance_factor)
                );

                state <- "waiting_food";
            }

        // --- TAKEAWAY ---
        } else {

            state <- "waiting_food";
        }
    }
    
    reflex go_to_table
	when: state = "going_to_table" {
	
	    if seat_position != nil {
	
	        do goto target: seat_position speed: 1.5;
	
	        if distance_to(location, seat_position) < 1 {
	
	            state <- "seated";
	        }
	    }
	}

    /****************************************
     *        WAITING FOR THE FOOD
     ****************************************/

    // Move to takeaway waiting zone
    reflex move_takeaway_area
    when: state = "waiting_food" and takeaway {

        do goto target: any_location_in(waiting_area) speed: 2.0;
    }

    // Waiting logic
    reflex wait_food
	when: (state = "seated" or state = "waiting_food") and every(20#cycle) {
	
	    waiting_for_food_time <- waiting_for_food_time + 1;

        if waiting_for_food_time > (effective_food_wait * 0.5) {

		    do change_satisfaction(
		        -(0.2 * annoyance_factor)
		    );
		}
		
		if waiting_for_food_time > effective_food_wait {
		
		    do change_satisfaction(
		        -(25 * annoyance_factor)
		    );
		
		    if assigned_table != nil {
		        assigned_table.occupied_seats <- assigned_table.occupied_seats - 1;
		        assigned_table <- nil;
		    }
		
		    state <- "leaving_frustrated";
		}
	}
	
	action receive_food(Cook from_cook) {
        waiting_for_food_time <- 0.0;
        if not takeaway {
            state <- "eating";
        } else {
            if (from_cook != nil) {
                assigned_counter <- from_cook.target_counter;
                target <- assigned_counter.location;
                state <- "picking_up_takeaway";
            } else {
                state <- "leaving";
            }
        }
    }
    
    reflex pickup_takeaway
    when: state = "picking_up_takeaway" {

        do goto(speed: 2.0, target: target);

        if distance_to(location, target) < 2.0 {

            // Récupéré → libérer le comptoir et partir
            if assigned_counter != nil {
                assigned_counter.is_occupied <- false;
                assigned_counter <- nil;
            }

            do change_satisfaction(10);
            state <- "leaving";
        }
    }

    /****************************************
     *               EATING
     ****************************************/

    // Customer eats at the table
    reflex eat
    when: state = "eating" and every(1#cycle) {

        eating_time <- eating_time + 1;

        if eating_time > rnd(15,30) {

            if assigned_table != nil {
                assigned_table.occupied_seats <- assigned_table.occupied_seats - 1;
                assigned_table <- nil;
            }

            do change_satisfaction(20);
            state <- "leaving";
        }
    }

    action handle_abandonment {
        do change_satisfaction(-50);
        if (assigned_counter != nil) { assigned_counter.is_occupied <- false; assigned_counter <- nil; }
        if (assigned_table != nil) { assigned_table.occupied_seats <- assigned_table.occupied_seats - 1; assigned_table <- nil; }
        ask world { do update_metrics(myself.satisfaction, 0.0, false); }
        state <- "leaving_frustrated";
    }

    /****************************************
     *              LEAVING
     ****************************************/

    reflex leave
    when: state = "leaving" {

        // --- Customer exits building first ---
        if is_in {

            target <- entrance.location;

            if distance_to(location, target) < 4.0 {
                is_in <- false;
            }

            if target != nil {
                do goto(speed: 3.0, target: target);
            }

        // --- Then walks away outside ---
        } else {

            if direction_left {
                target <- left_sidewalk;
            } else {
                target <- right_sidewalk;
            }

            if target != nil {

                do goto(speed: 3.0, target: target);

                if distance_to(location, target) < 2.0 {
                    // Update Global KPIs
                    ask world { do update_metrics(myself.satisfaction, myself.waiting_for_food_time, true); }
                    do die;
                }
            }
        }
    }
    
    reflex leave_frustrated
    when: state = "leaving_frustrated" {
        target <- entrance.location;
        do goto(speed: 3.5, target: target); // Walk faster when angry
        
        if distance_to(location, target) < 4.0 {
            is_in <- false;
            state <- "leaving_frustrated_outside";
        }
    }
    
    reflex leave_frustrated_outside
    when: state = "leaving_frustrated_outside" {
        target <- direction_left ? left_sidewalk : right_sidewalk;
        do goto(speed: 3.5, target: target);
        if distance_to(location, target) < 1.0 {
            do die;
        }
    }
    
    action change_satisfaction(int amount) {

	    satisfaction <- satisfaction + amount;
	
	    if satisfaction > 150 {
	        satisfaction <- 100;
	    }
	
	    if satisfaction < 0 {
	        satisfaction <- 0;
	    }
	}

    /****************************************
     *             VISUALS
     ****************************************/

aspect base {

        rgb col <- #gray;

        switch customer_type {
            match "regular"  { col <- #dodgerblue; }
            match "vip"      { col <- #gold; }
            match "impatient"{ col <- #crimson; }
            match "foodie"   { col <- #mediumorchid; }
        }

        if state = "waiting_for_counter" { col <- #lightyellow; }
        if state = "ordering"            { col <- darker(col); }
        if state = "waiting_food"        { col <- #orange; }
        if state = "eating"              { col <- #limegreen; }
        if state = "picking_up_takeaway" { col <- #yellowgreen; }

        if state = "leaving" {
            if satisfaction < 30 {
                col <- #black;
            } else {
                col <- #darkred;
            }
        }

        draw circle(2.0) color: col border: #white;
    }
}