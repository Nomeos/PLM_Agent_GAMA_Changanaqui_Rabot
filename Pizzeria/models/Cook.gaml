/**
* Name: cooker
* Defining agent cooker 
* Author: root
* Tags: 
*/


model Cook

import "Pizzeria.gaml"
import "Counter.gaml"
import "Machine.gaml"

species Cook skills: [moving] {

    string personality   <- "normal";
    int abandon_threshold <- 6;

    string  state          <- "idle";
    Counter target_counter <- nil;
    Machine target_machine <- nil;

    map<string, int> current_order <- map([]);
    int tasks_total    <- 0;
    int tasks_done     <- 0;
    int work_remaining <- 0;
    list<Machine> used_machines <- [];

    int wait_at_counter <- 0;

    init {
        personality <- one_of(["normal", "lazy", "explorer", "quitter"]);
        write "Cook " + self + " personality: " + personality;
    }

    int compute_tasks_total (map<string, int> order) {
        int total <- 0;
        loop item over: order.keys {
            total <- total + round(menu[item] / 5) * order[item];
        }
        return total;
    }

    map<string, int> generate_order {
        list<string> items <- shuffle(menu.keys);
        int nb_items       <- rnd(2, 3);
        map<string, int> order <- map([]);
        loop i from: 0 to: nb_items - 1 {
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
        if personality = "lazy" {
            return candidates with_min_of (each distance_to self);
        } else if personality = "explorer" {
            return candidates with_max_of (each distance_to self);
        } else {
            return one_of(candidates);
        }
    }

    reflex seek_counter when: state = "idle" {
        list<Counter> free <- counter_stations where (each.is_occupied = false);
        if length(free) > 0 {
            target_counter <- one_of(free);
        } else {
            target_counter <- one_of(counter_stations);
        }
        state <- "going_to_counter";
        write "Cook " + self + " [" + personality + "] → counter " + target_counter;
    }

    reflex move_to_counter when: state = "going_to_counter" {
        if target_counter = nil { state <- "idle"; return; }

        list<Counter> free <- counter_stations where (each.is_occupied = false and each != target_counter);
        if target_counter.is_occupied and length(free) > 0 {
            target_counter <- one_of(free);
            write "Cook " + self + " redirected to free counter " + target_counter;
        }

        point wait_spot <- target_counter.location + {3.0, 0.0};
        do goto(speed: cook_speed, target: wait_spot);

        if (self distance_to target_counter) < 3.5 {
            if target_counter.is_occupied = false {
                target_counter.is_occupied  <- true;
                target_counter.current_cook <- self;
                wait_at_counter             <- 0;
                state                       <- "waiting_for_order";
                write "Cook " + self + " at counter — waiting for client...";
            }
        }
    }

    reflex wait_for_order when: state = "waiting_for_order" {
        wait_at_counter <- wait_at_counter + 1;
        if wait_at_counter >= order_wait_time {
            current_order <- generate_order();
            tasks_total   <- compute_tasks_total(current_order);
            tasks_done    <- 0;
            used_machines <- [];

            if personality = "quitter" and tasks_total > abandon_threshold {
                write "Cook " + self + " [quitter] order too long (" + tasks_total + " tasks), skipping!";
                target_counter.is_occupied  <- false;
                target_counter.current_cook <- nil;
                target_counter <- nil;
                current_order  <- map([]);
                tasks_total    <- 0;
                state          <- "idle";
                return;
            }

            write "Cook " + self + " [" + personality + "] got order: " + current_order + " → " + tasks_total + " tasks";
            state <- "choosing_machine";
        }
    }

    reflex choose_machine when: state = "choosing_machine" {
        if tasks_done >= tasks_total {
            state <- "going_back_to_counter";
            write "Cook " + self + " finished all " + tasks_total + " tasks → delivering";
            return;
        }

        list<Machine> available <- work_stations where (not (used_machines contains each));
        if length(available) = 0 {
            used_machines <- [];
            available     <- work_stations;
        }

        target_machine <- pick_machine(available);
        state          <- "going_to_machine";
        write "Cook " + self + " [" + personality + "] → machine " + target_machine
              + " (task " + (tasks_done + 1) + "/" + tasks_total + ")";
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
                write "Cook " + self + " starts on machine " + target_machine
                      + " for " + work_remaining + " cycles";
            }
        }
    }

    reflex work when: state = "working" {
        work_remaining <- work_remaining - 1;
        if work_remaining <= 0 {
            target_machine.is_occupied  <- false;
            target_machine.current_cook <- nil;
            tasks_done     <- tasks_done + 1;
            target_machine <- nil;
            state          <- "choosing_machine";
        }
    }

    reflex go_back_to_counter when: state = "going_back_to_counter" {
        if target_counter = nil { state <- "idle"; return; }

        do goto(speed: cook_speed, target: target_counter);

        if (self distance_to target_counter) < 1.0 {
            float val       <- compute_order_value(current_order);
            restaurant_ca   <- restaurant_ca + val;
            served_customers <- served_customers + 1;
            write "Cook " + self + " delivers → +" + val + "€  (CA: " + restaurant_ca + "€)";

            target_counter.is_occupied  <- false;
            target_counter.current_cook <- nil;
            target_counter <- nil;
            current_order  <- map([]);
            tasks_total    <- 0;
            tasks_done     <- 0;
            used_machines  <- [];
            state          <- "idle";
        }
    }

    aspect base {
        rgb cook_color <- #blue;
        if state = "working" { cook_color <- #green; }
        else if state = "going_to_machine" or state = "going_to_counter" or state = "going_back_to_counter" { 
            cook_color <- #orange; 
        }
        else if state = "waiting_for_order" { cook_color <- #cyan; }
        else if state = "choosing_machine" { cook_color <- #yellow; }
        
        rgb border_color <- #white;
        if personality = "lazy" { border_color <- #grey; }
        else if personality = "explorer" { border_color <- #purple; }
        else if personality = "quitter" { border_color <- #red; }

        draw circle(3.0) color: cook_color border: border_color;

        string label <- "[" + first(personality) + "] " + state;
        if tasks_total > 0 { label <- label + " (" + tasks_done + "/" + tasks_total + ")"; }
        draw label font: font("Arial", 6, #plain) at: {location.x, location.y - 5} color: #black;
    }
}