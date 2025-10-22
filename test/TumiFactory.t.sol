// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import {TumiRegistry} from "../src/infra/TumiRegistry.sol";
import {TumiContractFactory} from "../src/infra/TumiContractFactory.sol";
import {IThirdwebContract} from "@thirdweb-dev/contracts/infra/interface/IThirdwebContract.sol";

contract MockContract is IThirdwebContract {
    string public contractURI;
    bytes32 public constant contractType = bytes32("MOCK");
    uint8 public constant contractVersion = 1;

    function setContractURI(string calldata _uri) external {
        contractURI = _uri;
    }
}

contract MockContractV2 is IThirdwebContract {
    string public contractURI;
    bytes32 public constant contractType = bytes32("MOCK");
    uint8 public constant contractVersion = 2;

    function setContractURI(string calldata _uri) external {
        contractURI = _uri;
    }
}

contract TumiContractFactoryTest is Test {
    TumiRegistry internal _registry;
    TumiContractFactory internal _factory;

    // Actors
    address internal actor;
    address internal proxyDeployer;
    address internal proxyDeployer2;

    // Test params
    MockContract internal mockModule;

    function setUp() public {
        actor = makeAddr("actor");
        vm.startPrank(actor);

        _registry = new TumiRegistry(address(0));
        _factory = new TumiContractFactory(address(0), address(_registry));
        _registry.grantRole(_registry.OPERATOR_ROLE(), address(_factory));

        mockModule = new MockContract();
        vm.stopPrank();

        proxyDeployer = makeAddr("proxyDeployer");
        proxyDeployer2 = makeAddr("proxyDeployer2");
    }

    /**
     *  @dev Tests the relevant initial state of the contract.
     *
     *  - Deployer of the contract has `FACTORY_ROLE`
     */
    function test_initialState() public view {
        assertTrue(_factory.hasRole(_factory.FACTORY_ROLE(), actor));
    }

    //  =====   Functionality tests   =====

    /// @dev Test `addImplementation`

    function test_addImplementation() public {
        bytes32 contractType = mockModule.contractType();
        uint256 moduleVersion = mockModule.contractVersion();
        uint256 moduleVersionOnFactory = _factory.currentVersion(contractType);

        vm.prank(actor);
        _factory.addImplementation(address(mockModule));

        assertTrue(_factory.approval(address(mockModule)));
        assertEq(address(mockModule), _factory.implementation(contractType, moduleVersion));
        assertEq(_factory.currentVersion(contractType), moduleVersionOnFactory + 1);
        assertEq(_factory.getImplementation(contractType, moduleVersion), address(mockModule));
    }

    function test_addImplementation_directV2() public {
        MockContractV2 mockModuleV2 = new MockContractV2();

        bytes32 contractType = mockModuleV2.contractType();
        uint256 moduleVersion = mockModuleV2.contractVersion();
        uint256 moduleVersionOnFactory = _factory.currentVersion(contractType);

        vm.prank(actor);
        _factory.addImplementation(address(mockModuleV2));

        assertTrue(_factory.approval(address(mockModuleV2)));
        assertEq(address(mockModuleV2), _factory.implementation(contractType, moduleVersion));
        assertEq(_factory.currentVersion(contractType), moduleVersionOnFactory + 2);
        assertEq(_factory.getImplementation(contractType, moduleVersion), address(mockModuleV2));
    }

    function test_addImplementation_newImpl() public {
        vm.prank(actor);
        _factory.addImplementation(address(mockModule));

        MockContractV2 mockModuleV2 = new MockContractV2();

        bytes32 contractType = mockModuleV2.contractType();
        uint256 moduleVersion = mockModuleV2.contractVersion();
        uint256 moduleVersionOnFactory = _factory.currentVersion(contractType);

        vm.prank(actor);
        _factory.addImplementation(address(mockModuleV2));

        assertTrue(_factory.approval(address(mockModuleV2)));
        assertEq(address(mockModuleV2), _factory.implementation(contractType, moduleVersion));
        assertEq(_factory.currentVersion(contractType), moduleVersionOnFactory + 1);
        assertEq(_factory.getImplementation(contractType, moduleVersion), address(mockModuleV2));
    }

    /// @dev Test `deployProxyByImplementation`

    function setUp_deployProxyByImplementation() internal {
        vm.prank(actor);
        _factory.approveImplementation(address(mockModule), true);
    }

    function test_deployProxyByImplementation(bytes32 _salt) public {
        setUp_deployProxyByImplementation();

        address computedProxyAddr = Clones.predictDeterministicAddress(
            address(mockModule),
            keccak256(abi.encodePacked(actor, _salt)),
            address(_factory)
        );

        vm.prank(actor);
        address deployedAddr = _factory.deployProxyByImplementation(address(mockModule), "", _salt);

        assertEq(deployedAddr, computedProxyAddr);
        assertEq(mockModule.contractType(), MockContract(computedProxyAddr).contractType());
    }

    function test_deployProxyByImplementation_twice() public {
        setUp_deployProxyByImplementation();

        vm.prank(actor);
        address deployedAddr = _factory.deployProxyByImplementation(address(mockModule), "", bytes32(uint256(0)));

        address computedProxyAddr = Clones.predictDeterministicAddress(
            address(mockModule),
            keccak256(abi.encodePacked(actor, bytes32(uint256(0)))),
            address(_factory)
        );

       

        vm.prank(actor);
        address deployedAddr2 = _factory.deployProxyByImplementation(address(mockModule), "", bytes32(uint256(1)));

        address computedProxyAddr2 = Clones.predictDeterministicAddress(
            address(mockModule),
            keccak256(abi.encodePacked(actor, bytes32(uint256(1)))),
            address(_factory)
        );

        assertEq(deployedAddr, computedProxyAddr);
        assertEq(deployedAddr2, computedProxyAddr2);
    }
}
