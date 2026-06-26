// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBerylBitsB20Like} from "./interfaces/IBerylBitsB20Like.sol";
import {IBerylBitsCurveSellLike} from "./interfaces/IBerylBitsCurveSellLike.sol";
import {BerylBitsB20NFTUpgradeable} from "./BerylBitsB20NFTUpgradeable.sol";
import {BerylBitsUpgradeableBase} from "./BerylBitsUpgradeableBase.sol";

contract BerylBitsB20ForgeUpgradeable is BerylBitsUpgradeableBase {
    using SafeERC20 for IERC20;

    uint256 public constant UNIT = 1 ether;

    IBerylBitsB20Like public token;
    BerylBitsB20NFTUpgradeable public nft;
    bool private _entered;
    IBerylBitsCurveSellLike public curve;

    error AmountZero();
    error EmptyRedeem();
    error CurveNotSet();
    error ZeroCurve();

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

    function initialize(address token_, address nft_, address admin) external initializer {
        __BerylBitsUpgradeableBase_init(admin);
        token = IBerylBitsB20Like(token_);
        nft = BerylBitsB20NFTUpgradeable(nft_);
    }

    function initializeV2(address curve_) external reinitializer(2) onlyRole(DEFAULT_ADMIN_ROLE) {
        if (curve_ == address(0)) revert ZeroCurve();
        curve = IBerylBitsCurveSellLike(curve_);
    }

    function setCurve(address curve_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (curve_ == address(0)) revert ZeroCurve();
        curve = IBerylBitsCurveSellLike(curve_);
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

    function redeemAndSell(uint256[] calldata tokenIds, uint256 minPayout) external nonReentrant whenNotPaused {
        uint256 quantity = tokenIds.length;
        if (quantity == 0) revert EmptyRedeem();
        IBerylBitsCurveSellLike curve_ = curve;
        if (address(curve_) == address(0)) revert CurveNotSet();

        for (uint256 i = 0; i < quantity; ++i) {
            nft.burnFromForge(msg.sender, tokenIds[i]);
        }

        uint256 amount = quantity * UNIT;
        token.mint(address(this), amount);
        IERC20(address(token)).forceApprove(address(curve_), amount);
        curve_.sellTo(quantity, minPayout, msg.sender);
        IERC20(address(token)).forceApprove(address(curve_), 0);
    }

    function _forge(address account, uint256 quantity) internal {
        if (quantity == 0) revert AmountZero();

        uint256 amount = quantity * UNIT;
        IERC20(address(token)).safeTransferFrom(account, address(this), amount);
        token.burn(amount);
        nft.mintFromForge(account, quantity);
    }
}
