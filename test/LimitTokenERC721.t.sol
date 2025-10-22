// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {TumiRegistry} from "../src/infra/TumiRegistry.sol";
import {TumiContractFactory} from "../src/infra/TumiContractFactory.sol";

import {LimitTokenERC721} from "../src/token/LimitTokenERC721.sol"; // adjust if your path differs
import {ITokenERC721} from "@thirdweb-dev/contracts/prebuilts/interface/token/ITokenERC721.sol";

contract LimitTokenERC721Test is Test {
    // ---- EIP712 constants to match the contract ----
    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    // Must exactly match the TYPEHASH used in LimitTokenERC721.sol
    bytes32 private constant MINT_REQUEST_TYPEHASH =
        keccak256(
            "MintRequest(address to,address royaltyRecipient,uint256 royaltyBps,address primarySaleRecipient,string uri,uint256 price,address currency,uint128 validityStartTimestamp,uint128 validityEndTimestamp,bytes32 uid)"
        );

    // Roles (must match the contract)
    bytes32 private constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // ---- Test actors / keys ----
    address internal admin;
    address internal saleRecipient;
    address internal platformFeeRecipient;
    address internal user;

    TumiRegistry _registry;
    TumiContractFactory _factory;
    address internal proxyAddress;
    address internal deployedAddr;

    uint256 internal minterPK;
    address internal minter; // signer that holds MINTER_ROLE (for signatures)

    function setUp() public {
        admin = address(0xA11CE);
        saleRecipient = address(0xBEEF);
        platformFeeRecipient = address(0xFEE);
        user = address(0xCAFE);

        // make block.timestamp > 0 for validity windows
        vm.warp(1 days);

        // Create signer
        minterPK = 0xA11CE; // any non-zero
        minter = vm.addr(minterPK);

        vm.startPrank(admin);

        _registry = new TumiRegistry(address(0));
        _factory = new TumiContractFactory(address(0), address(_registry));
        _registry.grantRole(_registry.OPERATOR_ROLE(), address(_factory));

        _factory.grantRole(_factory.FACTORY_ROLE(), user);
        _registry.grantRole(_registry.OPERATOR_ROLE(), user);

        proxyAddress = address(new LimitTokenERC721());

        _factory.addImplementation(proxyAddress);

        _factory.approveImplementation(proxyAddress, true);

        // deploy the proxy
        bytes32 contractType = LimitTokenERC721(proxyAddress).contractType();
        address[] memory trustedForwarders = new address[](1);
        trustedForwarders[0] = address(0);

        deployedAddr = _factory.deployProxy(
            contractType,
            abi.encodeWithSelector(
                LimitTokenERC721.initialize.selector,
                admin,
                "NewToken",
                "NTK",
                "https://example.com/new-token",
                trustedForwarders,
                admin,
                admin,
                0,
                0,
                admin
            )
        );
        LimitTokenERC721(deployedAddr).grantRole(MINTER_ROLE, minter);
        vm.stopPrank();
    }

    // ---------- Helpers ----------

    function _domainSeparator() internal view returns (bytes32) {
        // Must match OZ EIP712Upgradeable._domainSeparatorV4()
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN_TYPEHASH,
                    keccak256(bytes("LimitTokenERC721")),
                    keccak256(bytes("1")),
                    block.chainid,
                    address(deployedAddr)
                )
            );
    }

    function _hashMintRequest(
        ITokenERC721.MintRequest memory req
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    MINT_REQUEST_TYPEHASH,
                    req.to,
                    req.royaltyRecipient,
                    req.royaltyBps,
                    req.primarySaleRecipient,
                    keccak256(bytes(req.uri)),
                    req.price,
                    req.currency,
                    req.validityStartTimestamp,
                    req.validityEndTimestamp,
                    req.uid
                )
            );
    }

    function _signMintRequest(
        ITokenERC721.MintRequest memory req
    ) internal view returns (bytes memory sig) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _domainSeparator(),
                _hashMintRequest(req)
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(minterPK, digest);
        sig = abi.encodePacked(r, s, v);
    }

    function _defaultReq(
        address to
    ) internal view returns (ITokenERC721.MintRequest memory req) {
        req = ITokenERC721.MintRequest({
            to: to,
            royaltyRecipient: address(0),
            royaltyBps: 0,
            primarySaleRecipient: address(0),
            uri: "ipfs://example-metadata-1",
            price: 0,
            currency: address(0),
            validityStartTimestamp: uint128(block.timestamp - 1),
            validityEndTimestamp: uint128(block.timestamp + 1 days),
            uid: keccak256(abi.encodePacked(to, uint256(1)))
        });
    }

    // ---------- Tests ----------

    function test_initialize() public {
        vm.prank(admin);
        bool isOperator = _registry.hasRole(
            _registry.OPERATOR_ROLE(),
            address(_factory)
        );
        assertTrue(isOperator);
    }

    function test_mintWithSignature_respectsPerWalletLimit() public {
        // First mint should succeed
        ITokenERC721.MintRequest memory req1 = _defaultReq(user);
        bytes memory sig1 = _signMintRequest(req1);

        LimitTokenERC721 token = LimitTokenERC721(deployedAddr);

        vm.prank(user);
        uint256 tokenId1 = token.mintWithSignature(req1, sig1);
        assertEq(token.ownerOf(tokenId1), user);
        assertEq(token.mintedBy(user), true);

        // Second mint with the same wallet should revert due to limit
        ITokenERC721.MintRequest memory req2 = _defaultReq(user);
        req2.uri = "ipfs://example-metadata-2";
        req2.uid = keccak256(abi.encodePacked(user, uint256(2))); // new uid
        bytes memory sig2 = _signMintRequest(req2);

        vm.prank(user);
        vm.expectRevert(LimitTokenERC721.AlreadyMinted.selector);
        token.mintWithSignature(req2, sig2);
    }

    function test_differentWallets_eachCanMintOnce() public {
        address userA = address(0xAAA1);
        address userB = address(0xBBB2);

        // A mints
        ITokenERC721.MintRequest memory rA = _defaultReq(userA);
        LimitTokenERC721 token = LimitTokenERC721(deployedAddr);
        bytes memory sA = _signMintRequest(rA);
        vm.prank(userA);
        token.mintWithSignature(rA, sA);
        assertEq(token.mintedBy(userA), true);

        // B mints
        ITokenERC721.MintRequest memory rB = _defaultReq(userB);
        rB.uid = keccak256(abi.encodePacked(userB, uint256(11)));
        bytes memory sB = _signMintRequest(rB);
        vm.prank(userB);
        token.mintWithSignature(rB, sB);
        assertEq(token.mintedBy(userB), true);
    }

    function test_rejectsExpiredRequest() public {
        ITokenERC721.MintRequest memory req = _defaultReq(user);
        LimitTokenERC721 token = LimitTokenERC721(deployedAddr);

        // ensure we're comfortably in the future
        vm.warp(10 days);
        // Force expiry
        req.validityStartTimestamp = uint128(block.timestamp - 2 days);
        req.validityEndTimestamp = uint128(block.timestamp - 1 days);

        bytes memory sig = _signMintRequest(req);

        vm.prank(user);
        vm.expectRevert(bytes("request expired"));
        token.mintWithSignature(req, sig);
    }
}
