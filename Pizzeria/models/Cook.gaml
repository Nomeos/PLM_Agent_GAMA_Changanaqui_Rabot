/**
* Name: cooker
* Defining agent cooker 
* Author: root
* Tags: 
*/


model Cook

/* Insert your model definition here */

species Cook skills: [moving] {
    string state <- "idle";
    int workload <- 0;

    reflex move {
        do wander speed: 1.0 bounds: world.shape;
    }

    aspect base {
        draw circle(2.5) color: #firebrick border: #white;
        draw "Cook" font: font("Arial", 7, #plain) at: {location.x, location.y - 3} color: #black;
    }
}