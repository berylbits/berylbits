// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBerylBitsB20Like} from "./interfaces/IBerylBitsB20Like.sol";

contract BerylBitsB20Curve is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");

    uint256 public constant UNIT = 1 ether;
    uint256 public constant FEE_BPS = 800;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant PUBLIC_UNITS = 9_975;

    uint256[8] internal _bandCeilings = [uint256(1_250), 2_500, 3_750, 5_000, 6_250, 7_500, 8_750, 9_975];
    uint256[8] internal _bandPrices = [
        uint256(0.0005 ether),
        0.00065 ether,
        0.00085 ether,
        0.0011 ether,
        0.0014 ether,
        0.0018 ether,
        0.0023 ether,
        0.003 ether
    ];

    IBerylBitsB20Like public immutable token;
    address public immutable treasury;

    uint256 public marketOutstandingUnits;

    error AmountZero();
    error PublicCapExceeded();
    error InsufficientPayment(uint256 required, uint256 provided);
    error InsufficientLiquidity(uint256 required, uint256 available);
    error EtherTransferFailed();

    constructor(IBerylBitsB20Like token_, address admin, address treasury_) {
        token = token_;
        treasury = treasury_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSE_ROLE, admin);
    }

    function pause() external onlyRole(PAUSE_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSE_ROLE) {
        _unpause();
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

    function buy(uint256 unitCount) external payable nonReentrant whenNotPaused {
        uint256 totalCost = quoteBuy(unitCount);
        if (msg.value < totalCost) revert InsufficientPayment(totalCost, msg.value);

        uint256 mintAmount = unitCount * UNIT;
        marketOutstandingUnits += unitCount;
        token.mint(msg.sender, mintAmount);

        uint256 treasuryFee = (totalCost * FEE_BPS) / BPS_DENOMINATOR;
        if (treasuryFee != 0) {
            (bool feeSent,) = treasury.call{value: treasuryFee}("");
            if (!feeSent) revert EtherTransferFailed();
        }

        uint256 refund = msg.value - totalCost;
        if (refund != 0) {
            (bool refunded,) = msg.sender.call{value: refund}("");
            if (!refunded) revert EtherTransferFailed();
        }
    }

    function sell(uint256 unitCount) external nonReentrant whenNotPaused {
        uint256 payout = quoteSell(unitCount);
        if (address(this).balance < payout) revert InsufficientLiquidity(payout, address(this).balance);

        uint256 burnAmount = unitCount * UNIT;
        IERC20(address(token)).safeTransferFrom(msg.sender, address(this), burnAmount);
        token.burn(burnAmount);
        marketOutstandingUnits -= unitCount;

        (bool sent,) = msg.sender.call{value: payout}("");
        if (!sent) revert EtherTransferFailed();
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
            uint256 sellPrice = (_bandPrices[bandIndex] * (BPS_DENOMINATOR - FEE_BPS)) / BPS_DENOMINATOR;

            totalPayout += unitsInBand * sellPrice;
            cursor -= unitsInBand;
            remaining -= unitsInBand;
        }
    }

    receive() external payable {}
}
