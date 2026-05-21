/**
* Name: Machine
* Machine species 
* Author: root
* Tags: 
*/


model Machine

import "Pizzeria.gaml"

species Machine {
    int capacity <- 1;
    bool is_occupied <- false;
    Cook current_cook <- nil;
    int work_start_time <- 0;
    
    // IMPORTANT : Définir une forme par défaut si elle n'est pas héritée ou définie ailleurs
    geometry shape <- rectangle(5, 5); 

    init {
        // Syntaxe robuste pour ajouter à une liste globale
        if (work_stations != nil) {
            work_stations +<- shape;
        }
    }

    aspect base {
        rgb occ_color <- is_occupied ? #darkgray : #gray;
        draw shape color: occ_color border: #black;
        if is_occupied {
            draw "Busy" font: font("Arial", 4, #plain) color: #white;
        }
    }
}