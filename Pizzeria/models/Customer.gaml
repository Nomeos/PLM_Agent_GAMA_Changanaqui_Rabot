/**
 * Name: Customer
 * Description: Defines the behavior of customers inside the pizzeria
 * Author: Mathieu Rabot et Yoann Changanaqui
 */

model Customer

import "Pizzeria.gaml"

species Customer skills: [moving, simple_bdi] {

    /****************************************
     *           CUSTOMER DATA
     ****************************************/

    // --- Identity ---
    string customer_type;
    int max_food_wait;
	float annoyance_factor;

    // --- Movement / Position ---
    point target;
    bool direction_left <- false;
    bool is_in <- false;

    // --- Needs / Satisfaction ---
    int patience;
    int satisfaction;
    int hunger;

    // --- Timers ---
    float waiting_time <- 0.0;
    float decision_timer <- 0.0;
    float menu_time <- 0.0;
    float food_waiting_time <- 0.0;
    float eating_time <- 0.0;

    // --- State Machine ---
    string state;

    // --- Order Information ---
    string chosen_meal <- nil;
    bool takeaway <- false;

    // --- Table Management ---
    Table assigned_table <- nil;
    point seat_position <- nil;

    // --- Visual ---
    float radius <- 2.0;

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
	
	        // CLIENT NORMAL
	        match "regular" {
	
	            patience <- rnd(80,120);
	
	            max_food_wait <- rnd(60,90);
	
	            annoyance_factor <- 1.0;
	
	            hunger <- rnd(40,90);
	        }
	
	        // CLIENT VIP
	        match "vip" {
	
	            patience <- rnd(120,180);
	
	            max_food_wait <- rnd(90,140);
	
	            annoyance_factor <- 1.5;
	
	            satisfaction <- 120;
	
	            hunger <- rnd(50,100);
	        }
	
	        // CLIENT IMPATIENT
	        match "impatient" {
	
	            patience <- rnd(40,70);
	
	            max_food_wait <- rnd(25,45);
	
	            annoyance_factor <- 2.5;
	
	            hunger <- rnd(70,100);
	        }
	
	        // FOODIE
	        match "foodie" {
	
	            patience <- rnd(100,160);
	
	            max_food_wait <- rnd(70,120);
	
	            annoyance_factor <- 2.0;
	
	            hunger <- rnd(80,100);
	        }
	    }
	}

    /****************************************
     *        MOVE TO RESTAURANT
     ****************************************/

    // Customer walks toward the entrance
    reflex move_to_door
    when: state = "going_to_door" and every(3#cycle) {

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
    when: state = "arrived_at_door" and every(2#cycle) {

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
        if flip(0.6) and length(waiting_queue) < 8 {

            state <- "entering";
            target <- inside_point;

        } else {

            // Otherwise leave immediately
            state <- "leaving";
            target <- location + {rnd(-20,20), rnd(-20,20)};
        }
    }

    // Move inside the restaurant
    reflex enter
    when: state = "entering" and every(3#cycle) {

        do goto(speed: 2.0, target: target);

        is_in <- true;

        // Once inside, read the menu
        if distance_to(location, target) < 2.0 {
            state <- "reading_menu";
        }
    }

    /****************************************
     *            MENU READING
     ****************************************/

    // Customer takes time to choose a meal
    reflex read_menu
    when: state = "reading_menu" and every(1#cycle) {

        menu_time <- menu_time + 1;

        // Random reading duration
        if menu_time > rnd(5,15) {

            // Get all meals from menu
            list<string> meals <- menu.keys;

            // Random meal selection
            chosen_meal <- one_of(meals);

            state <- "ordering";
        }
    }

    /****************************************
     *             ORDERING
     ****************************************/

    // Add customer order to global pending order list
    reflex order_food
    when: state = "ordering" {

        pending_orders <- pending_orders + [[
            "customer"::self,
            "meal"::chosen_meal,
            "prep_time"::menu[chosen_meal],
            "progress"::0
        ]];

        state <- "choose_mode";
    }

    /****************************************
     *       DINE-IN OR TAKEAWAY
     ****************************************/

    // Decide if customer eats inside or takeaway
    reflex choose_eat_mode
    when: state = "choose_mode" {

        // Hungry customers are more likely to stay
        float dine_prob <- hunger / 100;

        takeaway <- not flip(dine_prob);

        // --- DINE IN ---
        if not takeaway {

            // Search for a free table
            Table free_table <- one_of(
			    Table where (each.has_free_seat())
			);

            // Table found
            if free_table != nil {

                assigned_table <- free_table;

                // Reserve one seat
                assigned_table.occupied_seats <- assigned_table.occupied_seats + 1;
				
				seat_position <- assigned_table.location +
				    assigned_table.seat_positions[
				        assigned_table.occupied_seats - 1
				    ];

                state <- "going_to_table";

            } else {

                // No table available -> forced takeaway
                takeaway <- true;

                // Customer is disappointed
                do change_satisfaction(
                	-(10 * annoyance_factor)
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

        do goto target: takeaway_waiting_area speed: 2.0;
    }

    // Waiting logic
    reflex wait_food
	when: state = "seated" or state = "waiting_food" and every(1#cycle) {
	
	    food_waiting_time <- food_waiting_time + 1;
	
	    // Perte progressive après un certain temps
	    if food_waiting_time > (max_food_wait * 0.5) {
	
	        do change_satisfaction(
	            -(0.2 * annoyance_factor)
	        );
	    }
	
	    // Trop attendu -> rage quit
	    if food_waiting_time > max_food_wait {
	
	        do change_satisfaction(-25 * annoyance_factor);
	
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

        // Finished eating
        if eating_time > rnd(15,30) {

            // Free table seat
            if assigned_table != nil {
            	assigned_table.occupied_seats <- assigned_table.occupied_seats - 1;
            }

            state <- "leaving";
        }
    }

    /****************************************
     *              LEAVING
     ****************************************/

    reflex leave
    when: state = "leaving" and every(3#cycle) {

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

                // Remove customer from simulation
                if distance_to(location, target) < 2.0 {
                	
                	served_customers <- served_customers + 1;

					restaurant_rating <- (
					    ((restaurant_rating * (served_customers - 1)) + satisfaction)
					    / served_customers
					);
                	
                    do die;
                }
            }
        }
    }
    
    action change_satisfaction(int amount) {

	    satisfaction <- satisfaction + amount;
	
	    if satisfaction > 100 {
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
	
	    // ========= TYPE =========
	
	    switch customer_type {
	
	        match "regular" {
	            col <- #dodgerblue;
	        }
	
	        match "vip" {
	            col <- #gold;
	        }
	
	        match "impatient" {
	            col <- #crimson;
	        }
	
	        match "foodie" {
	            col <- #mediumorchid;
	        }
	    }
	
	    // ========= ETAT =========
	
	    if state = "reading_menu" {
	        col <- darker(col);
	    }
	
	    if state = "waiting_food" {
	        col <- #orange;
	    }
	
	    if state = "eating" {
	        col <- #limegreen;
	    }
	
	    if state = "leaving" {
	
	        // rouge/noir si vraiment énervé
	        if satisfaction < 30 {
	            col <- #black;
	        } else {
	            col <- #darkred;
	        }
	    }
	
	    draw circle(radius) color: col border: #white;
	}
}