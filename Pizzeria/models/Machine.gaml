/**
* Name: Machine
* Machine species 
* Author: root
* Tags: 
*/


model Machine

/* Insert your model definition here */

species Machine {
    float cost <- 100.0;
    string state <- "idle";
    float failure_chance <- 0.01;

    aspect base {
        draw square(4) color: (state = "broken") ? #red : #gray border: #darkgray;
    }
}