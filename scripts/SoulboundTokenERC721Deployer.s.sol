// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";

import {TumiContractFactory} from "../src/infra/TumiContractFactory.sol";
import {SoulboundTokenERC721} from "../src/token/SoulboundTokenERC721.sol";

contract SoulboundTokenERC721Deployer is Script {
    TumiContractFactory internal _factory;
    SoulboundTokenERC721 internal _soulboundTokenERC721;

    function run() public {
        vm.createSelectFork("pharos-testnet");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        _factory = TumiContractFactory(
            0x06139E587b068Efa924A74f790d0045d6bF4992f
        );

        _soulboundTokenERC721 = new SoulboundTokenERC721();

        _factory.addImplementation(address(_soulboundTokenERC721));
        _factory.approveImplementation(address(_soulboundTokenERC721), true);
        vm.stopBroadcast();
    }
}
