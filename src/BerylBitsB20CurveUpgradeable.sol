// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBerylBitsB20Like} from "./interfaces/IBerylBitsB20Like.sol";
import {BerylBitsUpgradeableBase} from "./BerylBitsUpgradeableBase.sol";

contract BerylBitsB20CurveUpgradeable is BerylBitsUpgradeableBase {
    using SafeERC20 for IERC20;

    uint256 public constant UNIT = 1 ether;
    uint256 public constant BUY_FEE_BPS = 800;
    uint256 public constant SELL_PAYOUT_BPS = 9_200;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant PUBLIC_UNITS = 9_975;

    uint256[8] internal _bandCeilings;
    uint256[8] internal _bandPrices;

    IBerylBitsB20Like public token;
    address public treasury;
    uint256 public marketOutstandingUnits;

    bool private _entered;

    // --- V3 storage (appended for upgrade; do not reorder) ---
    // Credible on-chain commitment: the team wallet cannot pull ETH out of the
    // curve until public demand has pushed `marketOutstandingUnits` to the
    // unlock threshold, ensuring enough ETH backing exists before any team exit.
    address public teamWallet;
    uint256 public teamSellUnlockUnits;

    error AmountZero();
    error PublicCapExceeded();
    error InsufficientPayment(uint256 required, uint256 provided);
    error InsufficientLiquidity(uint256 required, uint256 available);
    error EtherTransferFailed();
    error RescueWouldBreakLiabilities(uint256 requested, uint256 excess);
    error CannotRescueB20();
    error CostExceedsMaximum(uint256 cost, uint256 maxCost);
    error PayoutBelowMinimum(uint256 payout, uint256 minPayout);
    error TeamSellLocked(uint256 currentUnits, uint256 unlockUnits);

    event TeamSellLockUpdated(address indexed teamWallet, uint256 unlockUnits);

    modifier nonReentrant() {
        require(!_entered, "REENTRANCY");
        _entered = true;
        _;
        _entered = false;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address token_, address admin, address treasury_) external initializer {
        __BerylBitsUpgradeableBase_init(admin);
        token = IBerylBitsB20Like(token_);
        treasury = treasury_;
        _bandCeilings = [uint256(1_250), 2_500, 3_750, 5_000, 6_250, 7_500, 8_750, 9_975];
        _bandPrices = [
            uint256(0.0005 ether),
            0.00065 ether,
            0.00085 ether,
            0.0011 ether,
            0.0014 ether,
            0.0018 ether,
            0.0023 ether,
            0.003 ether
        ];
    }

    function quoteBuy(uint256 unitCount) public view returns (uint256) {
        if (unitCount == 0) revert AmountZero();
        if (marketOutstandingUnits + unitCount > PUBLIC_UNITS) revert PublicCapExceeded();
        return _quoteAscending(marketOutstandingUnits, unitCount);
    }

    function quoteSell(uint256 unitCount) public view returns (uint256) {
        if (unitCount == 0) revert AmountZero();
        if (unitCount > marketOutstandingUnits) revert PublicCapExceeded();
        return _quoteDescending(marketOutstandingUnits, unitCount);
    }

    function curveLiability() public view returns (uint256) {
        if (marketOutstandingUnits == 0) return 0;
        return quoteSell(marketOutstandingUnits);
    }

    function excessETH() public view returns (uint256) {
        uint256 liability = curveLiability();
        if (address(this).balance <= liability) return 0;
        return address(this).balance - liability;
    }

    function buy(uint256 unitCount) external payable nonReentrant whenNotPaused {
        _buy(unitCount, type(uint256).max);
    }

    function buy(uint256 unitCount, uint256 maxCost) external payable nonReentrant whenNotPaused {
        _buy(unitCount, maxCost);
    }

    function sell(uint256 unitCount) external nonReentrant whenNotPaused {
        _sell(unitCount, 0, msg.sender);
    }

    function sell(uint256 unitCount, uint256 minPayout) external nonReentrant whenNotPaused {
        _sell(unitCount, minPayout, msg.sender);
    }

    function sellTo(uint256 unitCount, uint256 minPayout, address payoutRecipient) external nonReentrant whenNotPaused {
        _sell(unitCount, minPayout, payoutRecipient);
    }

    function _buy(uint256 unitCount, uint256 maxCost) internal {
        uint256 totalCost = quoteBuy(unitCount);
        if (totalCost > maxCost) revert CostExceedsMaximum(totalCost, maxCost);
        if (msg.value < totalCost) revert InsufficientPayment(totalCost, msg.value);

        marketOutstandingUnits += unitCount;
        token.mint(msg.sender, unitCount * UNIT);

        uint256 treasuryFee = (totalCost * BUY_FEE_BPS) / BPS_DENOMINATOR;
        if (treasuryFee != 0) _sendETH(treasury, treasuryFee);

        uint256 refund = msg.value - totalCost;
        if (refund != 0) _sendETH(msg.sender, refund);
    }

    function _sell(uint256 unitCount, uint256 minPayout, address payoutRecipient) internal {
        // Team exit is gated until public demand reaches the unlock threshold.
        // Checked on the ETH recipient so direct sells, sellTo, and redeemAndSell
        // routing all respect the same commitment.
        address teamWallet_ = teamWallet;
        if (teamWallet_ != address(0) && payoutRecipient == teamWallet_ && marketOutstandingUnits < teamSellUnlockUnits) {
            revert TeamSellLocked(marketOutstandingUnits, teamSellUnlockUnits);
        }

        uint256 payout = quoteSell(unitCount);
        if (payout < minPayout) revert PayoutBelowMinimum(payout, minPayout);
        if (address(this).balance < payout) revert InsufficientLiquidity(payout, address(this).balance);

        IERC20(address(token)).safeTransferFrom(msg.sender, address(this), unitCount * UNIT);
        token.burn(unitCount * UNIT);
        marketOutstandingUnits -= unitCount;

        _sendETH(payoutRecipient, payout);
    }

    function rescueExcessETH(address payable to, uint256 amount) external onlyRole(RESCUE_ROLE) nonReentrant {
        uint256 excess = excessETH();
        if (amount > excess) revert RescueWouldBreakLiabilities(amount, excess);
        _sendETH(to, amount);
    }

    /// @notice Set the team wallet and the public-demand threshold below which the
    /// team wallet cannot pull ETH out of the curve. Set `unlockUnits` to 0 to disable.
    function setTeamSellLock(address teamWallet_, uint256 unlockUnits) external onlyRole(DEFAULT_ADMIN_ROLE) {
        teamWallet = teamWallet_;
        teamSellUnlockUnits = unlockUnits;
        emit TeamSellLockUpdated(teamWallet_, unlockUnits);
    }

    function rescueERC20(address asset, address to, uint256 amount) external onlyRole(RESCUE_ROLE) {
        if (asset == address(token)) revert CannotRescueB20();
        IERC20(asset).safeTransfer(to, amount);
    }

    function bandCeilings() external view returns (uint256[8] memory) {
        return _bandCeilings;
    }

    function bandPrices() external view returns (uint256[8] memory) {
        return _bandPrices;
    }

    function _quoteAscending(uint256 startUnits, uint256 amount) internal view returns (uint256 totalCost) {
        uint256 remaining = amount;
        uint256 cursor = startUnits;

        for (uint256 i = 0; i < _bandCeilings.length && remaining != 0; ++i) {
            if (cursor >= _bandCeilings[i]) continue;
            uint256 availableInBand = _bandCeilings[i] - cursor;
            uint256 unitsInBand = remaining < availableInBand ? remaining : availableInBand;
            totalCost += unitsInBand * _bandPrices[i];
            cursor += unitsInBand;
            remaining -= unitsInBand;
        }
    }

    function _quoteDescending(uint256 startUnits, uint256 amount) internal view returns (uint256 totalPayout) {
        uint256 remaining = amount;
        uint256 cursor = startUnits;

        for (uint256 i = _bandCeilings.length; i > 0 && remaining != 0; --i) {
            uint256 bandIndex = i - 1;
            uint256 bandFloor = bandIndex == 0 ? 0 : _bandCeilings[bandIndex - 1];
            if (cursor <= bandFloor) continue;

            uint256 usedInBand = cursor - bandFloor;
            uint256 unitsInBand = remaining < usedInBand ? remaining : usedInBand;
            uint256 sellPrice = (_bandPrices[bandIndex] * SELL_PAYOUT_BPS) / BPS_DENOMINATOR;
            totalPayout += unitsInBand * sellPrice;
            cursor -= unitsInBand;
            remaining -= unitsInBand;
        }
    }

    function _sendETH(address to, uint256 amount) internal {
        (bool sent,) = to.call{value: amount}("");
        if (!sent) revert EtherTransferFailed();
    }

    receive() external payable {}
}
