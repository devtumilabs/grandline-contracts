// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";

import {TumiContractFactory} from "../src/infra/TumiContractFactory.sol";
import {OpenEditionERC721} from "../src/token/OpenEditionERC721.sol";
// import {SoulboundTokenERC721} from "../src/token/SoulboundTokenERC721.sol";
// import {TokenERC721} from "@thirdweb-dev/contracts/prebuilts/token/TokenERC721.sol";

contract OpenEditionERC721Deployer is Script {
    TumiContractFactory internal _factory;
    OpenEditionERC721 internal _openEdition;
    // SoulboundTokenERC721 internal _soulboundTokenERC721;
    // TokenERC721 internal _tokenERC721;
    function run() public {
        vm.createSelectFork("pharos-atlantic");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        _factory = TumiContractFactory(
            0x2445ccA88D3F819E7dC27A90e96dC684370e9f33
        );

        _openEdition = new OpenEditionERC721();
        // _soulboundTokenERC721 = new SoulboundTokenERC721();
        // _tokenERC721 = new TokenERC721();

        _factory.addImplementation(address(_openEdition));
        _factory.approveImplementation(address(_openEdition), true);
        vm.stopBroadcast();
    }
}
