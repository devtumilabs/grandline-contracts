// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {TumiRegistry} from "../src/infra/TumiRegistry.sol";
import {TumiContractFactory} from "../src/infra/TumiContractFactory.sol";

import {TokenERC721} from "@thirdweb-dev/contracts/prebuilts/token/TokenERC721.sol";

contract TumiCollectionTest is Test {
    TumiRegistry _registry;
    TumiContractFactory _factory;
    address internal proxyAddress;

    address internal admin;
    address internal user;

    function setUp() public {
        admin = makeAddr("admin");
        user = makeAddr("user");
        vm.startPrank(admin);
        
        _registry = new TumiRegistry(address(0));
        _factory = new TumiContractFactory(address(0), address(_registry));
        _registry.grantRole(_registry.OPERATOR_ROLE(), address(_factory));

        proxyAddress = address(new TokenERC721());

        _factory.addImplementation(proxyAddress);

        _factory.approveImplementation(proxyAddress, true);

        vm.stopPrank();
    }

    function test_initialize() public {
        vm.prank(admin);
        bool isOperator = _registry.hasRole(_registry.OPERATOR_ROLE(), address(_factory));
        assertTrue(isOperator);
    }

    /// @dev Test `deployProxyByImplementation`
    function test_deployProxyByImplementation() public {
        bytes32 contractType = TokenERC721(proxyAddress).contractType();
        address[] memory trustedForwarders = new address[](1);
        trustedForwarders[0] = address(0);
        vm.prank(user);
        address deployedAddr = _factory.deployProxy(contractType, abi.encodeWithSelector(TokenERC721.initialize.selector, user, "NewToken", "NTK", "https://example.com/new-token", trustedForwarders, user, user, 0, 0, user));

        console.logBytes(abi.encodeWithSelector(TokenERC721.initialize.selector, user, "NewToken", "NTK", "https://example.com/new-token", trustedForwarders, user, user, 0, 0, user));
        console.logBytes32(contractType);

        console.logAddress(deployedAddr);
        console.logUint(_registry.count(user));
        console.logString(TokenERC721(deployedAddr).name());

        bytes32 adminRole = TokenERC721(deployedAddr).DEFAULT_ADMIN_ROLE();

        assertEq(TokenERC721(deployedAddr).hasRole(adminRole, user), true);

        assertEq(TokenERC721(deployedAddr).name(), "NewToken");
    }
}
