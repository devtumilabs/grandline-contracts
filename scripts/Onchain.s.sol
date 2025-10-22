// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";

import {TumiContractFactory} from "../src/infra/TumiContractFactory.sol";
import {DropERC721} from "@thirdweb-dev/contracts/prebuilts/drop/DropERC721.sol";
import {TumiRegistry} from "../src/infra/TumiRegistry.sol";
import {SoulboundTokenERC721} from "../src/token/SoulboundTokenERC721.sol";

contract Onchain is Script {
    function run() public {
        vm.createSelectFork("pharos-testnet");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(deployerPrivateKey);
        address minter = 0xd22e2e7aca050b789bf34a08488f20C23A6cc7CD;
        // uint256 secondDeployerPrivateKey = vm.envUint("SECOND_PRIVATE_KEY");
        // address secondDeployer = vm.addr(secondDeployerPrivateKey);

        TumiContractFactory _factory = TumiContractFactory(
            0x06139E587b068Efa924A74f790d0045d6bF4992f
        );

        bytes32 contractType = bytes32("SoulboundTokenERC721");
        bytes32 minterRole = keccak256("MINTER_ROLE");
        address[] memory trustedForwarders = new address[](1);
        trustedForwarders[0] = address(0);

        vm.startBroadcast(deployerPrivateKey);

        // // deploy first contract
        address nereusProxy = _factory.deployProxy(
            contractType,
            abi.encodeWithSelector(
                SoulboundTokenERC721.initialize.selector,
                admin,
                "NEREUS",
                "NEREUS",
                "https://example.com/nereus",
                trustedForwarders,
                admin,
                admin,
                0,
                0,
                admin
            )
        );
        SoulboundTokenERC721 nereus = SoulboundTokenERC721(nereusProxy);
        nereus.grantRole(minterRole, minter);
        console.log("nereus", nereusProxy);

        // deploy second contract
        address pyxisProxy = _factory.deployProxy(
            contractType,
            abi.encodeWithSelector(
                SoulboundTokenERC721.initialize.selector,
                admin,
                "PYXIS",
                "PYXIS",
                "https://example.com/pyxis",
                trustedForwarders,
                admin,
                admin,
                0,
                0,
                admin
            )
        );
        SoulboundTokenERC721 pyxis = SoulboundTokenERC721(pyxisProxy);
        pyxis.grantRole(minterRole, minter);
        console.log("pyxis", pyxisProxy);

        // // deploy third contract
        address oceanusProxy = _factory.deployProxy(
            contractType,
            abi.encodeWithSelector(
                SoulboundTokenERC721.initialize.selector,
                admin,
                "OCEANUS",
                "OCEANUS",
                "https://example.com/oceanus",
                trustedForwarders,
                admin,
                admin,
                0,
                0,
                admin
            )
        );
        SoulboundTokenERC721 oceanus = SoulboundTokenERC721(oceanusProxy);
        oceanus.grantRole(minterRole, minter);
        console.log("oceanus", oceanusProxy);

        vm.stopBroadcast();
    }
}
