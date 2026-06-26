// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBerylBitsB20Like} from "./interfaces/IBerylBitsB20Like.sol";
import {BerylBitsB20NFT} from "./BerylBitsB20NFT.sol";

contract BerylBitsB20Forge is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");

    uint256 public constant UNIT = 1 ether;

    IBerylBitsB20Like public immutable token;
    BerylBitsB20NFT public immutable nft;

    error AmountZero();
    error EmptyRedeem();

    constructor(IBerylBitsB20Like token_, BerylBitsB20NFT nft_, address admin) {
        token = token_;
        nft = nft_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSE_ROLE, admin);
    }

    function pause() external onlyRole(PAUSE_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSE_ROLE) {
        _unpause();
    }

    function forge(uint256 quantity) external nonReentrant whenNotPaused {
        _forge(msg.sender, quantity);
    }

    function redeem(uint256[] calldata tokenIds) external nonReentrant whenNotPaused {
        uint256 quantity = tokenIds.length;
        if (quantity == 0) revert EmptyRedeem();

        for (uint256 i = 0; i < quantity; ++i) {
            nft.burnFromForge(msg.sender, tokenIds[i]);
        }

        token.mint(msg.sender, quantity * UNIT);
    }

    function _forge(address account, uint256 quantity) internal {
        if (quantity == 0) revert AmountZero();

        uint256 amount = quantity * UNIT;
        IERC20(address(token)).safeTransferFrom(account, address(this), amount);
        token.burn(amount);
        nft.mintFromForge(account, quantity);
    }
}
