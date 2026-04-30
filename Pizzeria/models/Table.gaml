/**
* Name: Table
* Table species 
* Author: root
* Tags: 
*/


model Table

/* Insert your model definition here */

species Table {
    int capacity <- 4;
    int max_capacity <- 4;
    string state <- "free";

    aspect base {
        draw square(5) color: (state = "free") ? #mediumseagreen : #tomato border: #white;
        draw state font: font("Arial", 7, #plain) at: {location.x, location.y - 3} color: #black;
    }
}