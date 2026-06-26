// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

interface IBerylBitsB20Like is IERC20, IERC20Permit {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
}

