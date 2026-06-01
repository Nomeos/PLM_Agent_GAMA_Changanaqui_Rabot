model Pizzeria

import "Cook.gaml"
import "Counter.gaml"
import "Machine.gaml"
import "Customer.gaml"
import "Table.gaml"

global {
    // ── Dimensions ─────────────────────────────────────────────────────────
    int width  <- 200;
    int height <- 200;
    geometry shape       <- rectangle(width, height);
    geometry kitchen     <- rectangle(width, 90)  at_location {width / 2, height - 40};
    geometry entrance    <- rectangle(40, 10)     at_location {width - 50, 25};
    geometry sidewalk    <- rectangle(width, 50)  at_location {width / 2, 0};
    geometry dining_area <- rectangle(110, 80)    at_location {70, 70};

    // ── Points de navigation ───────────────────────────────────────────────
    point door_location  <- {entrance.location.x, entrance.location.y - 10};
    point inside_point   <- {entrance.location.x, entrance.location.y + 40};
    point left_sidewalk  <- {20, 10};
    point right_sidewalk <- {width - 20, 10};
    point takeaway_waiting_area <- {width / 2, 40};

    // ── Paramètres clients ─────────────────────────────────────────────────
    int nb_customers   <- 10;
    int queue_capacity <- 8;
    int spawn_every    <- 5;
    list<Customer> waiting_queue <- [];
    
    // ── Paramètres cuisine ─────────────────────────────────────────────────
    int nb_cooks    <- 2;
    int nb_machines <- 4;
    int nb_counters <- 4;

    float cook_speed     <- 2.0;
    int min_task_time    <- 5;
    int max_task_time    <- 20;
    int order_wait_time  <- 15;

    // ── Menu (prix → tasks/unité = round(prix/5)) ──────────────────────────
    map<string, int> menu <- [
        "pizza_margherita" :: 15,
        "pizza_pepperoni"  :: 18,
        "salad"            :: 10,
        "drink"            :: 5
    ];

    list<Machine> work_stations    <- [];
    list<Counter> counter_stations <- [];
    int static_counter_id <- 0;
    
    list<map> pending_orders <- [];

    // ── Métriques ──────────────────────────────────────────────────────────
    float restaurant_ca     <- 0.0;
    float served_customers   <- 0;
    float restaurant_rating <- 100.0;
    float total_wait_time   <- 0.0;

    // ── Init ───────────────────────────────────────────────────────────────
    init {
        create Table number: 8 {
            location       <- any_location_in(dining_area);
            max_capacity   <- rnd(1, 4);
            occupied_seats <- 0;
        }

        create Customer number: nb_customers {
            if flip(0.5) {
                location       <- {left_sidewalk.x,  rnd(left_sidewalk.y  - 10, left_sidewalk.y  + 10)};
                direction_left <- false;
            } else {
                location       <- {right_sidewalk.x, rnd(right_sidewalk.y - 10, right_sidewalk.y + 10)};
                direction_left <- true;
            }
        }

        create Machine number: nb_machines {
            location <- any_location_in(kitchen);
        }

        create Counter number: nb_counters;

        create Cook number: nb_cooks {
            location <- {rnd(width), rnd(height - 50, height)};
        }

        work_stations    <- list(Machine);
        counter_stations <- list(Counter);
    }

    reflex manage_queue when: every(5 #cycle) {
        waiting_queue <- waiting_queue where (each.state = "in_queue" or each.state = "ordering");
    }

    reflex spawn_customers when: every(spawn_every #cycle) {
        if length(Customer) < nb_customers {
            create Customer number: 1 {
                if flip(0.5) {
                    location       <- {left_sidewalk.x,  rnd(left_sidewalk.y  - 10, left_sidewalk.y  + 10)};
                    direction_left <- false;
                } else {
                    location       <- {right_sidewalk.x, rnd(right_sidewalk.y - 10, right_sidewalk.y + 10)};
                    direction_left <- true;
                }
                state  <- "going_to_door";
                target <- door_location + {rnd(-2, 2), rnd(-2, 2)};
            }
        }
    }
}