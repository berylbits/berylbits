// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IBerylBitsB20Like} from "./interfaces/IBerylBitsB20Like.sol";

/// @notice Local-development token shim for Beryl Bits.
/// @dev The production Base deployment should use a native B20 asset created through the factory precompile.
contract BerylBitsB20Token is ERC20, ERC20Permit, AccessControl, Pausable, IBerylBitsB20Like {
    bytes32 public constant MINT_ROLE = keccak256("MINT_ROLE");
    bytes32 public constant BURN_ROLE = keccak256("BURN_ROLE");
    bytes32 public constant RESERVE_ROLE = keccak256("RESERVE_ROLE");
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");

    uint256 public constant MAX_SHARED_UNITS = 10_000 ether;
    uint256 public constant RESERVE_UNITS = 0;
    uint256 public constant PUBLIC_UNITS = MAX_SHARED_UNITS - RESERVE_UNITS;

    uint256 public reserveUnlockTimestamp;
    uint256 public reserveMintedUnits;

    error ReserveLocked();
    error ReserveExceeded();
    error MaxSupplyExceeded();

    constructor(address admin, uint256 reserveUnlockTimestamp_)
        ERC20("Beryl Bits", "BBITS")
        ERC20Permit("Beryl Bits")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSE_ROLE, admin);
        reserveUnlockTimestamp = reserveUnlockTimestamp_;
    }

    function pause() external onlyRole(PAUSE_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSE_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) external onlyRole(MINT_ROLE) whenNotPaused {
        _mintCapped(to, amount);
    }

    function burn(uint256 amount) external onlyRole(BURN_ROLE) whenNotPaused {
        _burn(msg.sender, amount);
    }

    function mintReserve(address to, uint256 amount) external onlyRole(RESERVE_ROLE) whenNotPaused {
        if (block.timestamp < reserveUnlockTimestamp) revert ReserveLocked();
        if (reserveMintedUnits + amount > RESERVE_UNITS) revert ReserveExceeded();

        reserveMintedUnits += amount;
        _mintCapped(to, amount);
    }

    function remainingReserveUnits() external view returns (uint256) {
        return RESERVE_UNITS - reserveMintedUnits;
    }

    function setReserveUnlockTimestamp(uint256 newUnlockTimestamp) external onlyRole(DEFAULT_ADMIN_ROLE) {
        reserveUnlockTimestamp = newUnlockTimestamp;
    }

    function _mintCapped(address to, uint256 amount) internal {
        if (totalSupply() + amount > MAX_SHARED_UNITS) revert MaxSupplyExceeded();
        _mint(to, amount);
    }

    function nonces(address owner) public view override(ERC20Permit, IERC20Permit) returns (uint256) {
        return super.nonces(owner);
    }
}
