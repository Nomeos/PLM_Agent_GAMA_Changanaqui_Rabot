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
        
        max_capacity <- rnd(1,4);

       list<point> possible_seats <- shuffle([
	        { offset, 0},
	        {-offset, 0},
	        {0,  offset},
	        {0, -offset}
	    ]);
	
	    seat_positions <- [];
	
	    loop i from: 0 to: min(max_capacity - 1, length(possible_seats) - 1) {
		    seat_positions <- seat_positions + [possible_seats[i]];
		}
    }
    
    bool has_free_seat {
	    return occupied_seats < max_capacity;
	}
	
	bool reserve_seat {
        if (occupied_seats < length(seat_positions)) {
            occupied_seats <- occupied_seats + 1;
            return true;
        }
        return false;
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