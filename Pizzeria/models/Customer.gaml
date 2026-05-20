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
    string customer_type <- "regular";

    // --- Movement / Position ---
    point target;
    bool direction_left <- false;
    bool is_in <- false;

    // --- Needs / Satisfaction ---
    float patience <- 80.0;
    float satisfaction <- 100.0;
    float hunger <- 100.0;

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

    // --- Visual ---
    float radius <- 2.0;

    /****************************************
     *              INIT
     ****************************************/

    init {
        state <- "going_to_door";
        target <- door_location;
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
                Table where (each.capacity > 0)
            );

            // Table found
            if free_table != nil {

                assigned_table <- free_table;

                // Reserve one seat
                assigned_table.capacity <- assigned_table.capacity - 1;

                state <- "waiting_food";

            } else {

                // No table available -> forced takeaway
                takeaway <- true;

                // Customer is disappointed
                satisfaction <- satisfaction - 15;

                state <- "waiting_food";
            }

        // --- TAKEAWAY ---
        } else {

            state <- "waiting_food";
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
    when: state = "waiting_food" and every(1#cycle) {

        food_waiting_time <- food_waiting_time + 1;

        // Too much waiting lowers satisfaction
        if food_waiting_time > 30 {
            satisfaction <- satisfaction - 20;
        }

        // Customer leaves if waiting too long
        if food_waiting_time > 60 {
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
                assigned_table.capacity <- assigned_table.capacity + 1;
            }

            state <- "leaving";
        }
    }

    /****************************************
     *         GENERIC WAIT STATE
     ****************************************/

    reflex wait
    when: state = "waiting" and every(2#cycle) {

        waiting_time <- waiting_time + 1.0;

        // Customer loses patience
        if waiting_time > patience {
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

            target <- entrance_door;

            if distance_to(location, target) < 2.0 {
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
                    do die;
                }
            }
        }
    }

    /****************************************
     *             VISUALS
     ****************************************/

    aspect base {

        rgb col <- #red;

        // Waiting customers
        if (state = "waiting") {
            col <- #orange;
        }

        // Eating customers
        else if (state = "eating") {
            col <- #limegreen;
        }

        draw circle(2.0) color: col border: #white;
    }
}