/**
* Name: Table
* Table species 
* Author: root
* Tags: 
*/


model Table

/* Insert your model definition here */

species Table {
    int occupied_seats;
    int max_capacity;
    list<point> seat_positions <- [];

    init {

        // Génération positions des sièges
        float offset <- 4.0;

       seat_positions <- [
		    { offset, 0},
		    {-offset, 0},
		    {0,  offset},
		    {0, -offset}
		];
    }
    
    bool has_free_seat {
	    return occupied_seats < max_capacity;
	}

    aspect base {

    rgb col <- #mediumseagreen;

    if occupied_seats = max_capacity {
        col <- #tomato;
    }

    draw square(6)
        color: col
        border: #white;

    // Dessine sièges
    loop seat over: seat_positions {

        draw circle(0.8)
    		at: (location + seat)
            color: #white
            border: #black;
    }
}
}