# Levy
LP governed MEV auctioned Hook.

# Problem Statement
An AMM pool holds two assets in a fixed relation (x.y=k). It’s price is the current ratio of those reserves. 
This price only updates when someone trades against the pool -- the pool itself has no awareness of the external market prize.

When the true market prize of the asset moves elsewhere, the pool's prize becomes stale. It continues quoting the old ratio until the first trade arrives to correct it. 
The one who executees the first trade captures the entire gap between the stale pool prize and the true market price, extracting it directly from the pool's reserves. This causes loss to LPs. 

This isn't one-off event.It happens with every price movement causing a structural drain for LPs.
Critically, the right to capture this value is currently up for grabs -- decided by gas auctions, private mempool access, and latency infrastructure. LPs bear 100% of the cost but have zero say in who wins it or where the extracted value goes.




