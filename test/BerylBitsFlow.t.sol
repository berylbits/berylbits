// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {BerylBitsB20Token} from "../src/BerylBitsB20Token.sol";
import {BerylBitsB20Curve} from "../src/BerylBitsB20Curve.sol";
import {BerylBitsB20Forge} from "../src/BerylBitsB20Forge.sol";
import {BerylBitsB20NFT} from "../src/BerylBitsB20NFT.sol";

contract BerylBitsFlowTest is Test {
    BerylBitsB20Token internal token;
    BerylBitsB20Curve internal curve;
    BerylBitsB20Forge internal forge;
    BerylBitsB20NFT internal nft;

    address internal admin = address(0xA11CE);
    address internal treasury = address(0xBEEF);
    address internal alice = address(0xCAFE);
    address internal bob = address(0xB0B);

    function setUp() external {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        token = new BerylBitsB20Token(admin, block.timestamp + 30 days);
        nft = new BerylBitsB20NFT(admin);
        forge = new BerylBitsB20Forge(token, nft, admin);
        curve = new BerylBitsB20Curve(token, admin, treasury);

        vm.startPrank(admin);
        token.grantRole(token.MINT_ROLE(), address(curve));
        token.grantRole(token.BURN_ROLE(), address(curve));
        token.grantRole(token.MINT_ROLE(), address(forge));
        token.grantRole(token.BURN_ROLE(), address(forge));
        token.grantRole(token.RESERVE_ROLE(), admin);
        nft.grantRole(nft.FORGE_ROLE(), address(forge));
        vm.stopPrank();
    }

    function testBuyForgeRedeemSellRoundTrip() external {
        vm.prank(alice);
        curve.buy{value: 0.0005 ether}(1);

        assertEq(token.balanceOf(alice), 1 ether);
        assertEq(curve.marketOutstandingUnits(), 1);
        assertEq(treasury.balance, 0.00004 ether);

        vm.startPrank(alice);
        token.approve(address(forge), 1 ether);
        forge.forge(1);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 0);
        assertEq(nft.ownerOf(1), alice);
        assertEq(curve.marketOutstandingUnits(), 1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        vm.prank(alice);
        forge.redeem(tokenIds);

        assertEq(token.balanceOf(alice), 1 ether);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(curve.marketOutstandingUnits(), 1);

        vm.prank(alice);
        token.approve(address(curve), 1 ether);

        uint256 quote = curve.quoteSell(1);
        uint256 balanceBefore = alice.balance;

        vm.prank(alice);
        curve.sell(1);

        assertEq(curve.marketOutstandingUnits(), 0);
        assertEq(token.balanceOf(alice), 0);
        assertEq(alice.balance, balanceBefore + quote);
    }

    function testReserveMintingIsDisabled() external {
        vm.prank(admin);
        vm.expectRevert(BerylBitsB20Token.ReserveLocked.selector);
        token.mintReserve(admin, 1 ether);

        vm.warp(block.timestamp + 31 days);

        vm.prank(admin);
        vm.expectRevert(BerylBitsB20Token.ReserveExceeded.selector);
        token.mintReserve(admin, 1 ether);

        assertEq(token.balanceOf(admin), 0);
        assertEq(token.reserveMintedUnits(), 0);
    }

    function testTokenUriWorks() external {
        vm.prank(alice);
        curve.buy{value: 0.0005 ether}(1);

        vm.startPrank(alice);
        token.approve(address(forge), 1 ether);
        forge.forge(1);
        vm.stopPrank();

        string memory uri = nft.tokenURI(1);
        assertTrue(bytes(uri).length > 0);
    }

    function testTokenImageIsTextFreePixelArt() external {
        vm.prank(alice);
        curve.buy{value: 0.0005 ether}(1);

        vm.startPrank(alice);
        token.approve(address(forge), 1 ether);
        forge.forge(1);
        vm.stopPrank();

        string memory svg = nft.imageSVG(1);
        assertFalse(_contains(svg, "<text"));
        assertFalse(_contains(svg, "font-"));
        assertTrue(_contains(svg, "<rect"));
        assertTrue(_contains(svg, "shape-rendering=\"crispEdges\""));
    }

    function testPublicCapBlocksBuy() external {
        vm.startPrank(alice);
        vm.expectRevert(BerylBitsB20Curve.PublicCapExceeded.selector);
        curve.quoteBuy(9_976);
        vm.stopPrank();
    }

    function testNftCapUsesLiveSupplyNotLifetimeMints() external {
        vm.startPrank(address(forge));
        nft.mintFromForge(alice, 10_000);
        nft.burnFromForge(alice, 1);
        nft.mintFromForge(alice, 1);
        vm.stopPrank();

        assertEq(nft.totalMinted(), 10_001);
        assertEq(nft.liveSupply(), 10_000);
        assertEq(nft.ownerOf(10_001), alice);
    }

    function testBuyRequiresExactOrHigherPayment() external {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(BerylBitsB20Curve.InsufficientPayment.selector, 0.0005 ether, 0.0004 ether));
        curve.buy{value: 0.0004 ether}(1);
    }

    function testZeroAmountsRevert() external {
        vm.expectRevert(BerylBitsB20Curve.AmountZero.selector);
        curve.quoteBuy(0);

        vm.expectRevert(BerylBitsB20Curve.AmountZero.selector);
        curve.quoteSell(0);

        vm.prank(alice);
        vm.expectRevert(BerylBitsB20Forge.AmountZero.selector);
        forge.forge(0);

        uint256[] memory ids = new uint256[](0);
        vm.prank(alice);
        vm.expectRevert(BerylBitsB20Forge.EmptyRedeem.selector);
        forge.redeem(ids);
    }

    function testUnauthorizedTokenMintAndBurnAreBlocked() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                token.MINT_ROLE()
            )
        );
        vm.prank(alice);
        token.mint(alice, 1 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                token.BURN_ROLE()
            )
        );
        vm.prank(alice);
        token.burn(1 ether);
    }

    function testUnauthorizedNftMintAndBurnAreBlocked() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                nft.FORGE_ROLE()
            )
        );
        vm.prank(alice);
        nft.mintFromForge(alice, 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                nft.FORGE_ROLE()
            )
        );
        vm.prank(alice);
        nft.burnFromForge(alice, 1);
    }

    function testUnauthorizedRoleGrantIsBlocked() external {
        bytes32 defaultAdminRole = token.DEFAULT_ADMIN_ROLE();
        bytes32 mintRole = token.MINT_ROLE();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                defaultAdminRole
            )
        );
        vm.prank(alice);
        token.grantRole(mintRole, alice);
    }

    function testPauseBlocksCurveAndForgeFlows() external {
        vm.prank(admin);
        curve.pause();

        vm.prank(alice);
        vm.expectRevert();
        curve.buy{value: 0.0005 ether}(1);

        vm.prank(admin);
        curve.unpause();

        vm.prank(alice);
        curve.buy{value: 0.0005 ether}(1);

        vm.prank(admin);
        forge.pause();

        vm.startPrank(alice);
        token.approve(address(forge), 1 ether);
        vm.expectRevert();
        forge.forge(1);
        vm.stopPrank();
    }

    function testCannotRedeemSomeoneElsesNft() external {
        vm.prank(alice);
        curve.buy{value: 0.0005 ether}(1);

        vm.startPrank(alice);
        token.approve(address(forge), 1 ether);
        forge.forge(1);
        vm.stopPrank();

        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        vm.prank(bob);
        vm.expectRevert(BerylBitsB20NFT.NotTokenOwner.selector);
        forge.redeem(ids);
    }

    function testCannotSellWithoutLiquidity() external {
        vm.prank(alice);
        curve.buy{value: 0.0005 ether}(1);

        vm.deal(address(curve), 0);

        vm.startPrank(alice);
        token.approve(address(curve), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(BerylBitsB20Curve.InsufficientLiquidity.selector, 0.00046 ether, 0));
        curve.sell(1);
        vm.stopPrank();
    }

    function testCapAndAccountingInvariantAcrossRoundTrip() external {
        vm.prank(alice);
        curve.buy{value: 0.0015 ether}(3);

        assertEq(curve.marketOutstandingUnits(), 3);
        assertEq(token.totalSupply(), 3 ether);
        assertEq(nft.balanceOf(alice), 0);

        vm.startPrank(alice);
        token.approve(address(forge), 2 ether);
        forge.forge(2);
        vm.stopPrank();

        assertEq(curve.marketOutstandingUnits(), 3);
        assertEq(token.totalSupply(), 1 ether);
        assertEq(token.balanceOf(alice), 1 ether);
        assertEq(nft.balanceOf(alice), 2);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;

        vm.prank(alice);
        forge.redeem(ids);

        assertEq(curve.marketOutstandingUnits(), 3);
        assertEq(token.totalSupply(), 3 ether);
        assertEq(token.balanceOf(alice), 3 ether);
        assertEq(nft.balanceOf(alice), 0);
    }

    function testReentrantSellerCannotDrainCurve() external {
        ReentrantSeller attacker = new ReentrantSeller(curve, token);
        vm.deal(address(attacker), 1 ether);

        attacker.buyOne{value: 0.0005 ether}();
        assertEq(token.balanceOf(address(attacker)), 1 ether);

        uint256 attackerEthBefore = address(attacker).balance;
        attacker.sellOne();

        assertEq(token.balanceOf(address(attacker)), 0);
        assertEq(curve.marketOutstandingUnits(), 0);
        assertEq(address(attacker).balance, attackerEthBefore + 0.00046 ether);
    }

    function testReentrantForgeReceiverCannotCreateExtraValue() external {
        ReentrantForgeReceiver receiver = new ReentrantForgeReceiver(curve, forge, token);
        vm.deal(address(receiver), 1 ether);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        receiver.buyApproveAndForge{value: 0.0005 ether}();

        assertEq(token.balanceOf(address(receiver)), 0);
        assertEq(nft.balanceOf(address(receiver)), 0);
        assertEq(curve.marketOutstandingUnits(), 0);
        assertEq(token.totalSupply(), 0);
    }

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length == 0 || n.length > h.length) return false;

        for (uint256 i = 0; i <= h.length - n.length; ++i) {
            bool matched = true;
            for (uint256 j = 0; j < n.length; ++j) {
                if (h[i + j] != n[j]) {
                    matched = false;
                    break;
                }
            }
            if (matched) return true;
        }

        return false;
    }
}

contract ReentrantSeller {
    BerylBitsB20Curve internal immutable curve;
    BerylBitsB20Token internal immutable token;
    bool internal reentered;

    constructor(BerylBitsB20Curve curve_, BerylBitsB20Token token_) {
        curve = curve_;
        token = token_;
    }

    function buyOne() external payable {
        curve.buy{value: msg.value}(1);
    }

    function sellOne() external {
        token.approve(address(curve), 1 ether);
        curve.sell(1);
    }

    receive() external payable {
        if (!reentered) {
            reentered = true;
            try curve.sell(1) {} catch {}
        }
    }
}

contract ReentrantForgeReceiver {
    BerylBitsB20Curve internal immutable curve;
    BerylBitsB20Forge internal immutable forge;
    BerylBitsB20Token internal immutable token;

    constructor(BerylBitsB20Curve curve_, BerylBitsB20Forge forge_, BerylBitsB20Token token_) {
        curve = curve_;
        forge = forge_;
        token = token_;
    }

    function buyApproveAndForge() external payable {
        curve.buy{value: msg.value}(1);
        token.approve(address(forge), 1 ether);
        forge.forge(1);
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata) external returns (bytes4) {
        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenId;
        forge.redeem(ids);
        return this.onERC721Received.selector;
    }
}
