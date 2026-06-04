/**
* Name: cooker
* Defining agent cooker 
* Author: root
* Tags: 
*/


model Cook

/**
 * The Cook agent manages the lifecycle of an order: from greeting the customer 
 * to processing tasks at various machines and delivering the final product.
 */
import "Pizzeria.gaml"
import "Counter.gaml"
import "Machine.gaml"

species Cook skills: [moving] {

    string personality; // normal, explorer, quitter
    int abandon_threshold <- rnd(4, 6); 

    string  state          <- "idle";
    Counter target_counter <- nil;
    Counter last_counter   <- nil;
    Machine target_machine <- nil;
    Customer my_customer   <- nil;

    map<string, int> current_order <- map([]);
    int tasks_total    <- 0;
    int tasks_done     <- 0;
    int work_remaining <- 0;
    list<Machine> used_machines <- [];

    init {
        personality <- one_of(["normal", "explorer", "quitter"]);
    }

    // --- Utility Methods ---
    // increase the workload for the cook.
    int compute_tasks_total (map<string, int> order) {
        int total <- 0;
        loop item over: order.keys {
            total <- total + max([1, round(menu[item] / 15.0)]) * order[item];
        }
        return total;
    }

    // Procedural generation of a customer's command
    map<string, int> generate_order {
        list<string> items <- shuffle(menu.keys); // Randomize order content
        int nb_items       <- rnd(1, 3);
        map<string, int> order <- map([]);
        int limit <- min([nb_items, length(items)]) - 1;
        loop i from: 0 to: limit {
            order[items[i]] <- rnd(1, 3);
        }
        return order;
    }

    float compute_order_value (map<string, int> order) {
        float total <- 0.0;
        loop item over: order.keys {
            total <- total + float(menu[item] * order[item]);
        }
        return total;
    }

    Machine pick_machine (list<Machine> candidates) {
        if personality = "explorer" {
            return candidates with_max_of (each distance_to self);
        } else {
            return one_of(candidates);
        }
    }

    reflex seek_counter when: state = "idle" {
        // Proactive search: prioritize counters where a customer is waiting
        list<Counter> busy_counters <- counter_stations where (!empty(Customer at_distance 2.0 overlapping each));
        list<Counter> cook_free_counters <- counter_stations where (empty(Cook at_distance 2.0 overlapping each));
        
        list<Counter> candidates <- (busy_counters inter cook_free_counters) - last_counter;
        
        if empty(candidates) { candidates <- cook_free_counters; }
        if empty(candidates) { candidates <- counter_stations; }
        
        target_counter <- one_of(candidates);
        state <- "going_to_counter";
    }

    reflex move_to_counter when: state = "going_to_counter" {
        if target_counter = nil { state <- "idle"; return; }

        point wait_spot <- target_counter.location + {2.0, 2.0};
        do goto(speed: cook_speed, target: wait_spot);

        if (self distance_to target_counter) < 3.5 {
            // We don't set is_occupied because that belongs to the Customer logic
            state <- "waiting_for_order";
        }
    }

    // Interaction: Direct communication between Cook and Customer.
    // The Cook 'picks up' the customer
    reflex wait_for_order when: state = "waiting_for_order" {
        // Find the specific customer assigned to the counter this cook is at
        list<Customer> potential_clients <- Customer where (each.state = "ordering" and each.assigned_counter = target_counter);
        
        if !empty(potential_clients) {
            Customer target_cust <- first(potential_clients);
            
            // Pre-calculate to see if personality allows taking this order
            map<string, int> temp_order <- generate_order();
            int temp_tasks <- compute_tasks_total(temp_order);

            // Order accepted: Bind the customer and advance their state
            my_customer   <- target_cust;
            current_order <- temp_order;
            tasks_total   <- temp_tasks;
            tasks_done    <- 0;
            used_machines <- [];

            // Update global item popularity statistics
            loop item over: current_order.keys {
                ask world { item_usage[item] <- item_usage[item] + myself.current_order[item]; }
            }

            ask my_customer {
                state <- "choose_mode";
            }

            state <- "choosing_machine";
        }
    }

    // Selection of work station based on personality (Explorer vs Normal)
    reflex choose_machine when: state = "choosing_machine" {
        if tasks_done >= tasks_total {
            state <- "going_back_to_counter";
            return;
        }

        list<Machine> available <- work_stations where (not (used_machines contains each));
        if length(available) = 0 {
            used_machines <- [];
            available     <- work_stations;
        }

        target_machine <- pick_machine(available);
        state          <- "going_to_machine";
    }

    reflex move_to_machine when: state = "going_to_machine" {
        if target_machine = nil { state <- "choosing_machine"; return; }

        point wait_spot <- target_machine.location + {3.0, 0.0};
        do goto(speed: cook_speed, target: wait_spot);

        if (self distance_to target_machine) < 3.5 {
            if target_machine.is_occupied = false {
                target_machine.is_occupied  <- true;
                target_machine.current_cook <- self;
                used_machines               <- used_machines + [target_machine];
                work_remaining              <- rnd(min_task_time, max_task_time);
                state                       <- "working";
            }
        }
    }

    // Working: task execution based on personality
    reflex work when: state = "working" {
        work_remaining <- work_remaining - 1;
        if work_remaining <= 0 {
            target_machine.is_occupied  <- false;
            target_machine.current_cook <- nil;
            tasks_done     <- tasks_done + 1;
            target_machine <- nil;
            
            // Quitter check midway
            if personality = "quitter" and tasks_done >= abandon_threshold and tasks_done < tasks_total {
                if (my_customer != nil) {
                    ask my_customer { do handle_abandonment; }
                }
                my_customer <- nil;
                current_order <- map([]);
                tasks_total <- 0;
                tasks_done <- 0;
                state <- "idle";
            } else {
                state          <- "choosing_machine";
            }
        }
    }

    // Finalizing order: Returning to customer to deliver food
    reflex go_back_to_counter when: state = "going_back_to_counter" {
        if target_counter = nil { state <- "idle"; return; }

        do goto(speed: cook_speed, target: target_counter);

        if (self distance_to target_counter) < 3.5 {
            if (my_customer != nil) {
                restaurant_ca <- restaurant_ca + compute_order_value(current_order);
                ask my_customer { do receive_food(myself); }
            }

            // Reset cook and customer reference
            last_counter   <- target_counter;
            target_counter <- nil;
            my_customer    <- nil;
            current_order  <- map([]);
            tasks_total    <- 0;
            tasks_done     <- 0;
            used_machines  <- [];
            state          <- "idle";
        }
    }

    aspect base {
        rgb my_cook_color <- #cyan;
        if state = "working" { my_cook_color <- #green; }
        if state = "moving_to_station" { my_cook_color <- #orange; }
        if state = "waiting" { my_cook_color <- #cyan; }
        
        draw circle(2.5) color: my_cook_color border: #white;
        draw state font: font("Arial", 6, #plain) at: {location.x, location.y - 4} color: #black;
    }
}