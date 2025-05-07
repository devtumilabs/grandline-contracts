// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";

/// @notice Infra Contracts
import { TumiRegistry } from "../src/infra/TumiRegistry.sol";
import { TumiContractFactory } from "../src/infra/TumiContractFactory.sol";

/// @notice ERC721 Contracts
import { TokenERC721 } from "@thirdweb-dev/contracts/prebuilts/token/TokenERC721.sol";
import { DropERC721 } from "@thirdweb-dev/contracts/prebuilts/drop/DropERC721.sol";

/// @notice ERC1155 Contracts
import { TokenERC1155 } from "@thirdweb-dev/contracts/prebuilts/token/TokenERC1155.sol";
import { DropERC1155 } from "@thirdweb-dev/contracts/prebuilts/drop/DropERC1155.sol";

contract InfraDeployer is Script {
    /// @notice Infra Contracts
    TumiRegistry internal _registry;
    TumiContractFactory internal _factory;

    /// @notice ERC721 Contracts
    TokenERC721 internal _collection;
    DropERC721 internal _collectionDrop;

    /// @notice ERC1155 Contracts
    TokenERC1155 internal _pack;
    DropERC1155 internal _packDrop;

    function run() public {
        // Create a new fork of the pharos network
        vm.createSelectFork("pharos");

        string memory output;
        string memory jsonKey = "output";

        // setup deployer
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 secondDeployerPrivateKey = vm.envUint("SECOND_PRIVATE_KEY");
        address secondDeployer = vm.addr(secondDeployerPrivateKey);

        // start deployment
        vm.startBroadcast(deployerPrivateKey);

        // deploy infra contracts
        _registry = new TumiRegistry(address(0));
        output = stdJson.serialize(jsonKey, "registry", address(_registry));
        _factory = new TumiContractFactory(address(0), address(_registry));
        output = stdJson.serialize(jsonKey, "factory", address(_factory));
        _registry.grantRole(_registry.OPERATOR_ROLE(), address(_factory));

        // grant second deployer role
        _registry.grantRole(_registry.OPERATOR_ROLE(), secondDeployer);
        _factory.grantRole(_factory.FACTORY_ROLE(), secondDeployer);

        // deploy erc721 contracts
        _collection = new TokenERC721();
        _collectionDrop = new DropERC721();

        // deploy erc1155 contracts
        _pack = new TokenERC1155();
        _packDrop = new DropERC1155();

        // add implementations to factory
        _factory.addImplementation(address(_collection));
        _factory.addImplementation(address(_collectionDrop));
        _factory.addImplementation(address(_pack));
        _factory.addImplementation(address(_packDrop));

        // approve implementations
        _factory.approveImplementation(address(_collection), true);
        _factory.approveImplementation(address(_collectionDrop), true);
        _factory.approveImplementation(address(_pack), true);
        _factory.approveImplementation(address(_packDrop), true);

        vm.stopBroadcast();
        string memory latestOutputPath = "./output/infra-latest.json";
        string memory currentOutputPath = string.concat("./output/infra-", vm.toString(vm.getBlockNumber()),".json");

        stdJson.write(output, latestOutputPath);
        stdJson.write(output, currentOutputPath);
    }

}

