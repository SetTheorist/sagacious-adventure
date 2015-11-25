module creature;

import std.stdio;

class body_part {
    string      name;
    body_part   parent;
    body_part[] children;
    bool        f_wield;
    bool        f_ring;
    bool        f_brain;
    bool        f_support;
    bool        f_organs;
};

struct body_part_spec {
    string      name;
    string      parent;
    string[]    children;
    real        p_wield;
    real        p_ring;
    real        p_brain;
    real        p_support;
    real        p_organs;
};

body_part_spec[] body_part_specs;
static this() {
    body_part_specs = [
        body_part_spec("head", "torso",     [], 0.0, 0.0, 1.0, 0.0, 0.0),
        body_part_spec("torso", "",         [], 0.0, 0.0, 0.0, 0.0, 1.0),
        body_part_spec("leg", "torso",      [], 0.0, 0.0, 0.0, 0.0, 0.0),
        body_part_spec("foot", "leg",       [], 0.0, 0.0, 0.0, 1.0, 0.0),
        body_part_spec("arm", "torso",      [], 0.0, 0.0, 0.0, 0.0, 0.0),
        body_part_spec("hand", "arm",       [], 1.0, 1.0, 0.0, 0.0, 0.0),
        body_part_spec("tentacle", "torso", [], 0.5, 0.5, 0.0, 0.5, 0.0),
        body_part_spec("claw", "arm",       [], 0.5, 0.5, 0.0, 0.0, 0.0),
        body_part_spec("claw", "leg",       [], 0.0, 0.0, 0.0, 1.0, 0.0),
    ];
}

/*
Self --> Head^* + Torso
Torso --> Body + Covering + (Limb*2)^* + (Tail)?
Body --> Thorax | Vertebrate | Invertebrate
Head --> (Horns)? + Face + Covering + (Antennae)?
Horns --> horn | horn*2
Face --> (Eye^2)^* + Nose + Mouth + Ear^2
Covering --> skin | fur/hair | scales | feathers | slime | chitin | shell
Limb --> Arm | Leg | Tentacle | Wing | Fin
Arm --> arm + Hand
Hand --> hand | claw | mitten | 
Leg --> leg + Foot
Foot --> (foot | hoof | claw | webbed | sucker | paw | ) + (claws)?
Eye -> eye | stalk | fly
Tail -> prehensile | long | short | stinger | fin 

+ coloring / patterning / thickness / hardness / ...
*/