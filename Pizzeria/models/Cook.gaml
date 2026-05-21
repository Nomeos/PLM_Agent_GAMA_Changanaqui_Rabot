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
    string state <- "looking_for_station"; 
    geometry target_station <- nil;
    int arrival_time <- 0; 
    int work_duration <- 0; 
    int wait_start_time <- 0;
    int wait_duration <- 5; 

    reflex choose_station when: state = "looking_for_station" {
        // CORRECTION CRITIQUE : Filtrer les listes d'AGENTS, pas de géométries
        list<Machine> free_machines_agents <- Machine where (each.is_occupied = false);
        list<Counter> free_counters_agents <- Counter where (each.is_occupied = false);
        
        // Extraire les formes pour le mouvement
        list<geometry> free_machines <- free_machines_agents collect each.shape;
        list<geometry> free_counters <- free_counters_agents collect each.shape;
        
        list<geometry> all_free <- free_machines + free_counters;
        
        if length(all_free) > 0 {
            target_station <- one_of(all_free);
            state <- "moving_to_station";
        } else {
            state <- "waiting";
            wait_start_time <- time; 
        }
    }

    reflex waiting_logic when: state = "waiting" {
        if (time - wait_start_time) >= wait_duration {
            state <- "looking_for_station";
        }
    }

    reflex move_to_station when: state = "moving_to_station" {
        if target_station != nil {
            do goto(speed: 2.0, target: target_station);
            
            if (location distance_to target_station) < 0.3 { 
                state <- "working";
                arrival_time <- time;
                work_duration <- rnd(5, 10);
                
                list<Machine> my_machine <- Machine where (shape = target_station);
                list<Counter> my_counter <- Counter where (shape = target_station);
                
                if length(my_machine) > 0 {
                    my_machine[0].is_occupied <- true;
                    my_machine[0].current_cook <- self;
                } else if length(my_counter) > 0 {
                    my_counter[0].is_occupied <- true;
                    my_counter[0].current_cook <- self;
                }
            }
        } else {
            state <- "looking_for_station";
        }
    }

    reflex work_on_station when: state = "working" {
        if (time - arrival_time) >= work_duration {
            state <- "looking_for_station";
            geometry current_work_place <- target_station;
            target_station <- nil;
            
            if current_work_place != nil {
                list<Machine> my_machine <- Machine where (shape = current_work_place);
                list<Counter> my_counter <- Counter where (shape = current_work_place);
                
                if length(my_machine) > 0 {
                    my_machine[0].is_occupied <- false;
                    my_machine[0].current_cook <- nil;
                } else if length(my_counter) > 0 {
                    my_counter[0].is_occupied <- false;
                    my_counter[0].current_cook <- nil;
                }
            }
        }
    }

    aspect base {
        rgb my_cook_color <- #firebrick;
        if state = "working" { my_cook_color <- #green; }
        if state = "moving_to_station" { my_cook_color <- #orange; }
        if state = "waiting" { my_cook_color <- #blue; }
        
        draw circle(2.5) color: my_cook_color border: #white;
        draw state font: font("Arial", 6, #plain) at: {location.x, location.y - 4} color: #black;
    }
}