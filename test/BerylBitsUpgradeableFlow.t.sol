// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {BerylBitsB20Token} from "../src/BerylBitsB20Token.sol";
import {BerylBitsB20CurveUpgradeable} from "../src/BerylBitsB20CurveUpgradeable.sol";
import {BerylBitsB20ForgeUpgradeable} from "../src/BerylBitsB20ForgeUpgradeable.sol";
import {BerylBitsB20NFTUpgradeable} from "../src/BerylBitsB20NFTUpgradeable.sol";
import {BerylBitsUpgradeableBase} from "../src/BerylBitsUpgradeableBase.sol";

contract BerylBitsUpgradeableFlowTest is Test {
    BerylBitsB20Token internal token;
    BerylBitsB20Token internal otherToken;
    BerylBitsB20CurveUpgradeable internal curve;
    BerylBitsB20ForgeUpgradeable internal forge;
    BerylBitsB20NFTUpgradeable internal nft;

    address internal admin = address(0xA11CE);
    address internal treasury = address(0xBEEF);
    address internal team = address(0x7EA);
    address internal multisig = address(0x5151);
    address internal timelock = address(0x710C);
    address internal alice = address(0xCAFE);
    address internal bob = address(0xB0B);

    function setUp() external {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(admin, 100 ether);

        token = new BerylBitsB20Token(admin, block.timestamp + 30 days);
        otherToken = new BerylBitsB20Token(admin, block.timestamp + 30 days);

        BerylBitsB20NFTUpgradeable nftImplementation = new BerylBitsB20NFTUpgradeable();
        nft = BerylBitsB20NFTUpgradeable(
            address(new ERC1967Proxy(address(nftImplementation), abi.encodeCall(BerylBitsB20NFTUpgradeable.initialize, (admin))))
        );

        BerylBitsB20ForgeUpgradeable forgeImplementation = new BerylBitsB20ForgeUpgradeable();
        forge = BerylBitsB20ForgeUpgradeable(
            address(
                new ERC1967Proxy(
                    address(forgeImplementation),
                    abi.encodeCall(BerylBitsB20ForgeUpgradeable.initialize, (address(token), address(nft), admin))
                )
            )
        );

        BerylBitsB20CurveUpgradeable curveImplementation = new BerylBitsB20CurveUpgradeable();
        curve = BerylBitsB20CurveUpgradeable(
            payable(
                address(
                    new ERC1967Proxy(
                        address(curveImplementation),
                        abi.encodeCall(BerylBitsB20CurveUpgradeable.initialize, (address(token), admin, treasury))
                    )
                )
            )
        );

        vm.startPrank(admin);
        token.grantRole(token.MINT_ROLE(), address(curve));
        token.grantRole(token.BURN_ROLE(), address(curve));
        token.grantRole(token.MINT_ROLE(), address(forge));
        token.grantRole(token.BURN_ROLE(), address(forge));
        nft.grantRole(nft.FORGE_ROLE(), address(forge));
        forge.initializeV2(address(curve));
        otherToken.grantRole(otherToken.MINT_ROLE(), admin);
        otherToken.mint(address(curve), 10 ether);
        curve.grantRole(curve.PAUSE_ROLE(), multisig);
        curve.grantRole(curve.RESCUE_ROLE(), multisig);
        curve.grantRole(curve.UPGRADER_ROLE(), timelock);
        curve.revokeRole(curve.UPGRADER_ROLE(), admin);
        vm.stopPrank();
    }

    function testUpgradeableFullRoundTripAndBurns() external {
        assertEq(token.balanceOf(admin), 0);
        assertEq(token.totalSupply(), 0);

        vm.prank(alice);
        curve.buy{value: 0.0005 ether}(1);

        assertEq(token.balanceOf(alice), 1 ether);
        assertEq(token.totalSupply(), 1 ether);
        assertEq(curve.marketOutstandingUnits(), 1);
        assertEq(treasury.balance, 0.00004 ether);
        assertEq(address(curve).balance, 0.00046 ether);

        vm.startPrank(alice);
        token.approve(address(forge), 1 ether);
        forge.forge(1);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), 0);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.liveSupply(), 1);
        assertEq(curve.marketOutstandingUnits(), 1);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        vm.prank(alice);
        forge.redeem(ids);

        assertEq(token.balanceOf(alice), 1 ether);
        assertEq(token.totalSupply(), 1 ether);
        assertEq(nft.liveSupply(), 0);
        vm.expectRevert(BerylBitsB20NFTUpgradeable.NonexistentToken.selector);
        nft.ownerOf(1);

        vm.startPrank(alice);
        token.approve(address(curve), 1 ether);
        uint256 payout = curve.quoteSell(1);
        uint256 balanceBefore = alice.balance;
        curve.sell(1);
        vm.stopPrank();

        assertEq(payout, 0.00046 ether);
        assertEq(alice.balance, balanceBefore + payout);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), 0);
        assertEq(curve.marketOutstandingUnits(), 0);
    }

    function testSlippageProtectedBuyAndSell() external {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(BerylBitsB20CurveUpgradeable.CostExceedsMaximum.selector, 0.0005 ether, 0.0004 ether));
        curve.buy{value: 0.0005 ether}(1, 0.0004 ether);

        vm.prank(alice);
        curve.buy{value: 0.0005 ether}(1, 0.0005 ether);

        vm.startPrank(alice);
        token.approve(address(curve), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(BerylBitsB20CurveUpgradeable.PayoutBelowMinimum.selector, 0.00046 ether, 0.0005 ether));
        curve.sell(1, 0.0005 ether);
        curve.sell(1, 0.00046 ether);
        vm.stopPrank();

        assertEq(curve.marketOutstandingUnits(), 0);
    }

    function testRedeemAndSellBurnsNftAndPaysEth() external {
        vm.prank(alice);
        curve.buy{value: 0.0005 ether}(1);
        vm.startPrank(alice);
        token.approve(address(forge), 1 ether);
        forge.forge(1);
        vm.stopPrank();

        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256 beforeBalance = alice.balance;

        vm.prank(alice);
        forge.redeemAndSell(ids, 0.00046 ether);

        assertEq(alice.balance, beforeBalance + 0.00046 ether);
        assertEq(token.balanceOf(address(forge)), 0);
        assertEq(token.balanceOf(alice), 0);
        assertEq(nft.liveSupply(), 0);
        assertEq(curve.marketOutstandingUnits(), 0);
        vm.expectRevert(BerylBitsB20NFTUpgradeable.NonexistentToken.selector);
        nft.ownerOf(1);
    }

    function testRedeemAndSellProtectsMinPayoutAndOwnership() external {
        vm.prank(alice);
        curve.buy{value: 0.0005 ether}(1);
        vm.startPrank(alice);
        token.approve(address(forge), 1 ether);
        forge.forge(1);
        vm.stopPrank();

        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(BerylBitsB20CurveUpgradeable.PayoutBelowMinimum.selector, 0.00046 ether, 0.0005 ether));
        forge.redeemAndSell(ids, 0.0005 ether);

        vm.prank(bob);
        vm.expectRevert(BerylBitsB20NFTUpgradeable.NotTokenOwner.selector);
        forge.redeemAndSell(ids, 0);
    }

    function testTeamAllocationIsDirectOffCurveMint() external {
        bytes32 mintRole = token.MINT_ROLE();

        vm.prank(admin);
        token.grantRole(mintRole, admin);

        vm.prank(admin);
        token.mint(team, 25 ether);

        vm.prank(admin);
        token.revokeRole(mintRole, admin);

        assertEq(token.balanceOf(team), 25 ether);
        assertEq(token.totalSupply(), 25 ether);
        assertEq(curve.marketOutstandingUnits(), 0);
    }

    function testCrystalArtIsTextFreeCenteredAndHasNoCharacterTraits() external {
        vm.prank(alice);
        curve.buy{value: 0.0005 ether}(1);
        vm.startPrank(alice);
        token.approve(address(forge), 1 ether);
        forge.forge(1);
        vm.stopPrank();

        string memory svg = nft.imageSVG(1);
        assertFalse(_contains(svg, "<text"));
        assertFalse(_contains(svg, "font-"));
        assertFalse(_contains(svg, "eye"));
        assertFalse(_contains(svg, "antenna"));
        assertFalse(_contains(svg, "aura"));
        assertTrue(_contains(svg, "<rect"));
        assertTrue(_contains(svg, "shape-rendering=\"crispEdges\""));
        assertTrue(_contains(svg, 'x="100"'));
        assertTrue(_contains(svg, 'x="200"'));
        assertTrue(_contains(svg, 'y="60"'));
        assertTrue(_contains(svg, 'y="240"'));

        string memory uri = nft.tokenURI(1);
        assertFalse(_contains(uri, "Eyes"));
        assertFalse(_contains(uri, "Aura"));
        assertFalse(_contains(uri, "Antenna"));
    }

    function testPauseBlocksCurveForgeAndNftTransfers() external {
        vm.prank(admin);
        curve.pause();
        vm.prank(alice);
        vm.expectRevert(BerylBitsUpgradeableBase.Paused.selector);
        curve.buy{value: 0.0005 ether}(1);

        vm.prank(admin);
        curve.unpause();
        vm.prank(alice);
        curve.buy{value: 0.0005 ether}(1);

        vm.prank(admin);
        forge.pause();
        vm.startPrank(alice);
        token.approve(address(forge), 1 ether);
        vm.expectRevert(BerylBitsUpgradeableBase.Paused.selector);
        forge.forge(1);
        vm.stopPrank();

        vm.prank(admin);
        forge.unpause();
        vm.startPrank(alice);
        forge.forge(1);
        vm.stopPrank();

        vm.prank(admin);
        nft.pause();
        vm.prank(alice);
        vm.expectRevert(BerylBitsUpgradeableBase.Paused.selector);
        nft.transferFrom(alice, bob, 1);
    }

    function testOnlyUpgraderCanUpgrade() external {
        BerylBitsB20CurveUpgradeable newImplementation = new BerylBitsB20CurveUpgradeable();
        bytes32 upgraderRole = curve.UPGRADER_ROLE();

        vm.expectRevert(abi.encodeWithSelector(BerylBitsUpgradeableBase.AccessDenied.selector, upgraderRole, alice));
        vm.prank(alice);
        curve.upgradeToAndCall(address(newImplementation), "");

        vm.expectRevert(abi.encodeWithSelector(BerylBitsUpgradeableBase.AccessDenied.selector, upgraderRole, admin));
        vm.prank(admin);
        curve.upgradeToAndCall(address(newImplementation), "");

        vm.prank(timelock);
        curve.upgradeToAndCall(address(newImplementation), "");
        assertEq(address(curve.token()), address(token));
    }

    function testMultisigCanPauseButCannotUpgrade() external {
        vm.prank(multisig);
        curve.pause();
        assertTrue(curve.paused());

        BerylBitsB20CurveUpgradeable newImplementation = new BerylBitsB20CurveUpgradeable();
        vm.expectRevert(abi.encodeWithSelector(BerylBitsUpgradeableBase.AccessDenied.selector, curve.UPGRADER_ROLE(), multisig));
        vm.prank(multisig);
        curve.upgradeToAndCall(address(newImplementation), "");
    }

    function testOnlyAdminCanGrantRoles() external {
        bytes32 adminRole = nft.DEFAULT_ADMIN_ROLE();
        bytes32 pauseRole = nft.PAUSE_ROLE();
        vm.expectRevert(abi.encodeWithSelector(BerylBitsUpgradeableBase.AccessDenied.selector, adminRole, alice));
        vm.prank(alice);
        nft.grantRole(pauseRole, alice);
    }

    function testRescueProtectsCurveLiabilities() external {
        vm.prank(alice);
        curve.buy{value: 0.0005 ether}(1);
        assertEq(curve.curveLiability(), 0.00046 ether);
        assertEq(curve.excessETH(), 0);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(BerylBitsB20CurveUpgradeable.RescueWouldBreakLiabilities.selector, 1, 0));
        curve.rescueExcessETH(payable(admin), 1);

        vm.deal(address(curve), address(curve).balance + 1 ether);
        uint256 adminBefore = admin.balance;
        vm.prank(admin);
        curve.rescueExcessETH(payable(admin), 1 ether);
        assertEq(admin.balance, adminBefore + 1 ether);
        assertEq(address(curve).balance, curve.curveLiability());
    }

    function testRescueERC20BlocksB20ButAllowsWrongToken() external {
        vm.prank(admin);
        vm.expectRevert(BerylBitsB20CurveUpgradeable.CannotRescueB20.selector);
        curve.rescueERC20(address(token), admin, 1 ether);

        uint256 before = otherToken.balanceOf(admin);
        vm.prank(admin);
        curve.rescueERC20(address(otherToken), admin, 1 ether);
        assertEq(otherToken.balanceOf(admin), before + 1 ether);
    }

    function testUnauthorizedBurnMintAndRedeemAreBlocked() external {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 1 ether);

        vm.prank(alice);
        curve.buy{value: 0.0005 ether}(1);
        vm.startPrank(alice);
        token.approve(address(forge), 1 ether);
        forge.forge(1);
        vm.stopPrank();

        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        vm.prank(bob);
        vm.expectRevert(BerylBitsB20NFTUpgradeable.NotTokenOwner.selector);
        forge.redeem(ids);
    }

    function testPublicCapAndTotalCapAreEnforced() external {
        vm.expectRevert(BerylBitsB20CurveUpgradeable.PublicCapExceeded.selector);
        curve.quoteBuy(9_976);

        vm.startPrank(address(forge));
        vm.expectRevert(BerylBitsB20NFTUpgradeable.SupplyExceeded.selector);
        nft.mintFromForge(alice, 10_001);
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

    function testInitializeV2IsAdminOnly() external {
        BerylBitsB20ForgeUpgradeable forgeImplementation = new BerylBitsB20ForgeUpgradeable();
        BerylBitsB20ForgeUpgradeable freshForge = BerylBitsB20ForgeUpgradeable(
            address(
                new ERC1967Proxy(
                    address(forgeImplementation),
                    abi.encodeCall(BerylBitsB20ForgeUpgradeable.initialize, (address(token), address(nft), admin))
                )
            )
        );

        vm.expectRevert(abi.encodeWithSelector(BerylBitsUpgradeableBase.AccessDenied.selector, freshForge.DEFAULT_ADMIN_ROLE(), alice));
        vm.prank(alice);
        freshForge.initializeV2(address(curve));

        vm.prank(admin);
        freshForge.initializeV2(address(curve));
        assertEq(address(freshForge.curve()), address(curve));
    }

    function testReentrantSellerCannotDrainCurve() external {
        ReentrantSellerUpgradeable attacker = new ReentrantSellerUpgradeable(curve, token);
        vm.deal(address(attacker), 1 ether);

        attacker.buyOne{value: 0.0005 ether}();
        uint256 attackerBefore = address(attacker).balance;
        attacker.sellOne();

        assertEq(token.balanceOf(address(attacker)), 0);
        assertEq(curve.marketOutstandingUnits(), 0);
        assertEq(address(attacker).balance, attackerBefore + 0.00046 ether);
    }

    function testReentrantForgeReceiverCannotCreateExtraValue() external {
        ReentrantForgeReceiverUpgradeable receiver = new ReentrantForgeReceiverUpgradeable(curve, forge, token);
        vm.deal(address(receiver), 1 ether);

        vm.expectRevert(BerylBitsB20NFTUpgradeable.InvalidReceiver.selector);
        receiver.buyApproveAndForge{value: 0.0005 ether}();

        assertEq(token.balanceOf(address(receiver)), 0);
        assertEq(nft.balanceOf(address(receiver)), 0);
        assertEq(token.totalSupply(), 0);
        assertEq(curve.marketOutstandingUnits(), 0);
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

    function testTeamSellLockBlocksExitUntilDemandThreshold() external {
        // Direct off-curve team allocation of 25 tokens.
        vm.startPrank(admin);
        token.grantRole(token.MINT_ROLE(), admin);
        token.mint(team, 25 ether);
        token.revokeRole(token.MINT_ROLE(), admin);
        // Team cannot pull ETH from the curve until 100 public units are outstanding.
        curve.setTeamSellLock(team, 100);
        vm.stopPrank();

        // Seed curve liquidity but stay below the unlock threshold.
        vm.prank(alice);
        curve.buy{value: 5 ether}(50, type(uint256).max);
        assertEq(curve.marketOutstandingUnits(), 50);

        // Team sell is blocked while outstanding < unlock threshold.
        vm.startPrank(team);
        token.approve(address(curve), 25 ether);
        vm.expectRevert(
            abi.encodeWithSelector(BerylBitsB20CurveUpgradeable.TeamSellLocked.selector, uint256(50), uint256(100))
        );
        curve.sell(1, 0);
        vm.stopPrank();

        // Public demand reaches the threshold.
        vm.prank(bob);
        curve.buy{value: 5 ether}(50, type(uint256).max);
        assertEq(curve.marketOutstandingUnits(), 100);

        // Team can now exit.
        uint256 before = team.balance;
        vm.prank(team);
        curve.sell(1, 0);
        assertGt(team.balance, before);
        assertEq(curve.marketOutstandingUnits(), 99);
    }

    function testTeamSellLockAppliesToRedeemAndSellRouting() external {
        vm.startPrank(admin);
        token.grantRole(token.MINT_ROLE(), admin);
        token.mint(team, 25 ether);
        token.revokeRole(token.MINT_ROLE(), admin);
        curve.setTeamSellLock(team, 100);
        vm.stopPrank();

        vm.prank(alice);
        curve.buy{value: 5 ether}(50, type(uint256).max);

        // Team forges a token to an NFT, then tries to redeemAndSell -> ETH to team is blocked.
        vm.startPrank(team);
        token.approve(address(forge), 1 ether);
        forge.forge(1);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        vm.expectRevert(
            abi.encodeWithSelector(BerylBitsB20CurveUpgradeable.TeamSellLocked.selector, uint256(50), uint256(100))
        );
        forge.redeemAndSell(ids, 0);
        vm.stopPrank();
    }

    function testMaxBuyPerWalletCapEnforcedAndConfigurable() external {
        vm.prank(admin);
        curve.setMaxBuyUnitsPerWallet(25);
        assertEq(curve.maxBuyUnitsPerWallet(), 25);

        // Alice can buy up to the cap across multiple txs.
        vm.startPrank(alice);
        curve.buy{value: 10 ether}(20, type(uint256).max);
        curve.buy{value: 10 ether}(5, type(uint256).max);
        assertEq(curve.curveBoughtUnits(alice), 25);

        // One more unit exceeds the cap.
        vm.expectRevert(abi.encodeWithSelector(BerylBitsB20CurveUpgradeable.WalletBuyCapExceeded.selector, uint256(26), uint256(25)));
        curve.buy{value: 1 ether}(1, type(uint256).max);
        vm.stopPrank();

        // The cap is per-wallet: bob still has his own allowance.
        vm.prank(bob);
        curve.buy{value: 10 ether}(25, type(uint256).max);
        assertEq(curve.curveBoughtUnits(bob), 25);

        // Admin can lift the cap; alice can then buy again.
        vm.prank(admin);
        curve.setMaxBuyUnitsPerWallet(0);
        vm.prank(alice);
        curve.buy{value: 10 ether}(10, type(uint256).max);
        assertEq(curve.curveBoughtUnits(alice), 25); // not tracked while disabled
    }
}

contract ReentrantSellerUpgradeable {
    BerylBitsB20CurveUpgradeable internal immutable curve;
    BerylBitsB20Token internal immutable token;
    bool internal reentered;

    constructor(BerylBitsB20CurveUpgradeable curve_, BerylBitsB20Token token_) {
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

contract ReentrantForgeReceiverUpgradeable is IERC721Receiver {
    BerylBitsB20CurveUpgradeable internal immutable curve;
    BerylBitsB20ForgeUpgradeable internal immutable forge;
    BerylBitsB20Token internal immutable token;

    constructor(BerylBitsB20CurveUpgradeable curve_, BerylBitsB20ForgeUpgradeable forge_, BerylBitsB20Token token_) {
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
