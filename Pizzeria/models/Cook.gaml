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
    string state <- "idle";
    float speed <- 1.0;
    
    Counter target_counter <- nil;
    Machine target_machine <- nil;    
    map<string, int> current_order <- nil;
    
    list<Machine> machines_to_use <- [];
    int current_machine_index <- 0;
    int work_remaining <- 0;
    
    reflex seek_counter when: state = "idle" {
        // Chercher un counter non occupé
        list<Counter> free_counters <- counter_stations where (each.is_occupied = false);
        if length(free_counters) > 0 {
            target_counter <- free_counters[0];
            target_counter.is_occupied <- true;
            target_counter.current_cook <- self;
            state <- "going_to_counter";
            write "Cook " + self + " goes to counter " + target_counter;
        } else {
            // Aucun counter libre, on attend (ne rien faire)
        }
    }
    
    reflex move_to_counter when: state = "going_to_counter" {
        if target_counter != nil {
            do goto(speed: 2.0, target: target_counter);
            if (self distance_to target_counter) < 1.0 {
                state <- "taking_order";
                write "Cook " + self + " arrived at counter " + target_counter;
            }
        } else {
            state <- "idle";
        }
    }
    
    reflex take_order when: state = "taking_order" {
        // Choisir un item au hasard dans le menu
        string chosen_item <- one_of(menu); // menu[rnd(length(menu))];
        current_order <- [chosen_item::menu[chosen_item]];
        write "Cook " + self + " takes order: " + chosen_item;
        
        // Sélectionner 3 machines (ou toutes si moins de 3)
        machines_to_use <- work_stations;
        if length(machines_to_use) > 3 {
            machines_to_use <- shuffle(machines_to_use);
        }
        current_machine_index <- 0;
        
        if length(machines_to_use) > 0 {
            target_machine <- machines_to_use[0];
            state <- "going_to_machine";
            write "Cook " + self + " goes to machine " + target_machine;
        } else {
            // Pas de machine du tout (cas improbable)
            write "No machines available!";
            target_counter.is_occupied <- false;
            target_counter.current_cook <- nil;
            target_counter <- nil;
            state <- "idle";
        }
    }
    
    reflex move_to_machine when: state = "going_to_machine" {
        if target_machine != nil {
            do goto(speed: 2.0, target: target_machine);
            
            if (self distance_to target_machine) < 0.1 {
                if target_machine.is_occupied = false {
                    // Prendre la machine
                    target_machine.is_occupied <- true;
                    target_machine.current_cook <- self;
                    work_remaining <- rnd(5, 15);  // durée de travail aléatoire
                    state <- "working";
                    write "Cook " + self + " starts working on machine " + target_machine + " for " + work_remaining + " cycles";
                } else {
                    // Machine occupée, attendre (rester dans le même état)
                    // On ne fait rien, le reflex sera réévalué au prochain cycle
                }
            }
        } else {
            state <- "idle";
        }
    }
    
    reflex work when: state = "working" {
        work_remaining <- work_remaining - 1;
        if work_remaining <= 0 {
            // Libérer la machine
            target_machine.is_occupied <- false;
            target_machine.current_cook <- nil;
            write "Cook " + self + " finished on machine " + target_machine;
            
            // Passer à la machine suivante
            current_machine_index <- current_machine_index + 1;
            if current_machine_index < length(machines_to_use) {
                target_machine <- machines_to_use[current_machine_index];
                state <- "going_to_machine";
                write "Cook " + self + " goes to next machine " + target_machine;
            } else {
                // Toutes les machines utilisées → retourner au counter
                state <- "going_back_to_counter";
                write "Cook " + self + " completed all machines, returning to counter";
            }
        }
    }
    
    reflex go_back_to_counter when: state = "going_back_to_counter" {
        if target_counter != nil {
            do goto(speed: 2.0, target: target_counter);
            if (self distance_to target_counter) < 1.0 {
                // Livrer la commande (pour l'instant, juste terminer)
                write "Cook " + self + " delivers order " + current_order + " at counter " + target_counter;
                // Libérer le counter
                target_counter.is_occupied <- false;
                target_counter.current_cook <- nil;
                target_counter <- nil;
                current_order <- nil;
                machines_to_use <- [];
                state <- "idle";
            }
        } else {
            state <- "idle";
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