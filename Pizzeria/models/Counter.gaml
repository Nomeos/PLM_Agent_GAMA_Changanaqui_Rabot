/**
* Name: Counter
* Based on the internal empty template. 
* Author: root
* Tags: 
*/


model Counter

import "Pizzeria.gaml"

species Counter {
    int capacity <- 1;
    bool is_occupied <- false;
    Cook current_cook <- nil;
    
    geometry shape <- rectangle(10, 5); // Forme explicite

    init {
        if (counter_stations != nil) {
            counter_stations +<- shape;
        }
    }

    aspect base {
        draw shape color: #orange border: #black;
        if is_occupied {
            draw "Busy" font: font("Arial", 4, #plain) color: #white;
        }
    }
}