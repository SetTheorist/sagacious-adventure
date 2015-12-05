module creature;

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
