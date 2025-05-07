// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";

import {TumiRegistry} from "../src/infra/TumiRegistry.sol";
import {TumiContractFactory} from "../src/infra/TumiContractFactory.sol";

contract TumiRegistryTest is Test {
    event Added(address indexed deployer, address indexed moduleAddress);
    event Deleted(address indexed deployer, address indexed moduleAddress);
   // Target contract
    TumiRegistry internal _registry;
    address internal factory;

    // Test params
    address internal mockModuleAddress = address(0x42);
    address internal actor;

    //  =====   Set up  =====

    function setUp() public {
        actor = makeAddr("actor");
        vm.startPrank(actor);
        _registry = new TumiRegistry(address(0));
        factory = address(new TumiContractFactory(address(0), address(_registry)));
        _registry.grantRole(_registry.OPERATOR_ROLE(), factory);
        vm.stopPrank();
    }

    //  =====   Functionality tests   =====

    function test_deploy() public {
        vm.startPrank(actor);
        bool isAdmin = _registry.hasRole(_registry.DEFAULT_ADMIN_ROLE(), actor);
        assertTrue(isAdmin);
        vm.stopPrank();
    }

    /// @dev Test `add`

    function test_addFromFactory() public {
        vm.startPrank(factory);
        _registry.add(actor, mockModuleAddress);

        address[] memory modules = _registry.getAll(actor);
        assertEq(modules.length, 1);
        assertEq(modules[0], mockModuleAddress);
        assertEq(_registry.count(actor), 1);

        _registry.add(actor, address(0x43));

        modules = _registry.getAll(actor);
        assertEq(modules.length, 2);
        assertEq(_registry.count(actor), 2);
        vm.stopPrank();
    }

    function test_addFromSelf() public {
        vm.prank(actor);
        _registry.add(actor, mockModuleAddress);

        address[] memory modules = _registry.getAll(actor);

        assertEq(modules.length, 1);
        assertEq(modules[0], mockModuleAddress);
        assertEq(_registry.count(actor), 1);
    }

    function test_add_emit_Added() public {
        vm.expectEmit(true, true, false, true);
        emit Added(actor, mockModuleAddress);

        vm.prank(factory);
        _registry.add(actor, mockModuleAddress);
    }
}
