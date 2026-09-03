# Levy
LP governed MEV auctioned Hook.

# Problem 
We know any pool holds two assets in a fixed relation (x.y=k, for AMM). It’s price is the current ratio of those reserves. 

This price moves when someone trades against the pool. The overall rate of 'x' or 'y' increases. However , in the pool old values are contained untill someone does the first trade. The one who trades first after the increment in rate gets good profit from it. After the first trade the value in the pool updates according to the current value. This causes loss to LPs. 

This happens with every price movement causing a structural drain for LPs . 



