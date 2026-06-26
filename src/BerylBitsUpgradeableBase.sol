// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

abstract contract BerylBitsUpgradeableBase is Initializable, UUPSUpgradeable {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant RESCUE_ROLE = keccak256("RESCUE_ROLE");

    mapping(bytes32 role => mapping(address account => bool allowed)) private _roles;
    bool public paused;

    error AccessDenied(bytes32 role, address account);
    error Paused();
    error NotPaused();

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event PausedStateChanged(bool paused);

    modifier onlyRole(bytes32 role) {
        _checkRole(role, msg.sender);
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert NotPaused();
        _;
    }

    function __BerylBitsUpgradeableBase_init(address admin) internal onlyInitializing {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSE_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(RESCUE_ROLE, admin);
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function grantRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_roles[role][account]) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    function pause() external onlyRole(PAUSE_ROLE) whenNotPaused {
        paused = true;
        emit PausedStateChanged(true);
    }

    function unpause() external onlyRole(PAUSE_ROLE) whenPaused {
        paused = false;
        emit PausedStateChanged(false);
    }

    function _checkRole(bytes32 role, address account) internal view {
        if (!_roles[role][account]) revert AccessDenied(role, account);
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!_roles[role][account]) {
            _roles[role][account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}
}
