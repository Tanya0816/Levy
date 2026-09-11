// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {LPAuctionHook} from "../src/LPAuctionHook.sol";

contract LPAuctionHookScript is Script {
    LPAuctionHook public auctionHook;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        auctionHook = new LPAuctionHook();

        vm.stopBroadcast();
    }
}
