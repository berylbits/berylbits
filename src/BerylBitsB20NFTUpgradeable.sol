// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {BerylBitsUpgradeableBase} from "./BerylBitsUpgradeableBase.sol";

contract BerylBitsB20NFTUpgradeable is BerylBitsUpgradeableBase {
    using Strings for uint256;

    bytes32 public constant FORGE_ROLE = keccak256("FORGE_ROLE");
    uint256 public constant MAX_SHARED_UNITS = 10_000;

    struct TraitSet {
        string berylColor;
        string cut;
        string facetPattern;
        string inclusion;
        string clarity;
        string backgroundName;
        string className;
        bool mythic;
        bool radiant;
    }

    string private _name;
    string private _symbol;
    uint256 public totalMinted;
    uint256 public liveSupply;

    mapping(uint256 tokenId => address owner) private _owners;
    mapping(address owner => uint256 balance) private _balances;
    mapping(uint256 tokenId => address approved) private _tokenApprovals;
    mapping(address owner => mapping(address operator => bool approved)) private _operatorApprovals;
    mapping(uint256 tokenId => bytes32 seed) public tokenSeed;

    error SupplyExceeded();
    error NotTokenOwner();
    error NonexistentToken();
    error InvalidReceiver();
    error NotApprovedOrOwner();
    error ZeroAddress();

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) external initializer {
        __BerylBitsUpgradeableBase_init(admin);
        _name = "Beryl Bits";
        _symbol = "BBITS-NFT";
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function balanceOf(address owner) public view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert NonexistentToken();
        return owner;
    }

    function approve(address to, uint256 tokenId) external whenNotPaused {
        address owner = ownerOf(tokenId);
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) revert NotApprovedOrOwner();
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        ownerOf(tokenId);
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external whenNotPaused {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public whenNotPaused {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotApprovedOrOwner();
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public whenNotPaused {
        transferFrom(from, to, tokenId);
        if (!_checkOnERC721Received(from, to, tokenId, data)) revert InvalidReceiver();
    }

    function mintFromForge(address to, uint256 quantity) external onlyRole(FORGE_ROLE) returns (uint256 firstTokenId) {
        if (to == address(0)) revert ZeroAddress();
        if (liveSupply + quantity > MAX_SHARED_UNITS) revert SupplyExceeded();

        firstTokenId = totalMinted + 1;
        for (uint256 i = 0; i < quantity; ++i) {
            uint256 tokenId = totalMinted + 1;
            totalMinted = tokenId;
            liveSupply += 1;
            tokenSeed[tokenId] = keccak256(abi.encode(to, tokenId, block.prevrandao, blockhash(block.number - 1)));
            _owners[tokenId] = to;
            _balances[to] += 1;
            emit Transfer(address(0), to, tokenId);

            if (to.code.length != 0 && !_checkOnERC721Received(address(0), to, tokenId, "")) revert InvalidReceiver();
        }
    }

    function burnFromForge(address owner, uint256 tokenId) external onlyRole(FORGE_ROLE) {
        if (ownerOf(tokenId) != owner) revert NotTokenOwner();
        delete _tokenApprovals[tokenId];
        delete _owners[tokenId];
        _balances[owner] -= 1;
        liveSupply -= 1;
        emit Transfer(owner, address(0), tokenId);
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        ownerOf(tokenId);
        TraitSet memory traits = traitSet(tokenId);

        string memory image = Base64.encode(bytes(_renderSvg(traits)));
        string memory json = Base64.encode(
            bytes(
                string.concat(
                    '{"name":"Beryl Bit #',
                    tokenId.toString(),
                    '","description":"Beryl Bits are Base-native 8-bit crystal relics forged from a shared B20 supply.",',
                    '"attributes":',
                    _attributesJson(traits),
                    ',"image":"data:image/svg+xml;base64,',
                    image,
                    '"}'
                )
            )
        );

        return string.concat("data:application/json;base64,", json);
    }

    function imageSVG(uint256 tokenId) external view returns (string memory) {
        ownerOf(tokenId);
        return _renderSvg(traitSet(tokenId));
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 || interfaceId == 0x80ac58cd || interfaceId == 0x5b5e139f;
    }

    function traitSet(uint256 tokenId) public view returns (TraitSet memory traits) {
        return _traitsFromSeed(tokenSeed[tokenId], tokenId);
    }

    /// @notice Render a crystal directly from a seed without minting. Useful for previews.
    function previewSVG(bytes32 seed, uint256 tokenId) external pure returns (string memory) {
        return _renderSvg(_traitsFromSeed(seed, tokenId));
    }

    function _traitsFromSeed(bytes32 seed, uint256 tokenId) internal pure returns (TraitSet memory traits) {
        traits.berylColor = _pickTrait(seed, 0, 100, [uint256(34), 58, 76, 89, 97, 100], ["Aquamarine", "Emerald", "Heliodor", "Morganite", "Goshenite", "Red Beryl"]);
        traits.cut = _pickTrait(seed, 1, 100, [uint256(34), 58, 76, 90, 98, 100], ["Hex", "Prism", "Shard", "Step", "Needle", "Royal"]);
        traits.facetPattern = _pickTrait(seed, 2, 100, [uint256(30), 54, 75, 90, 98, 100], ["Plain", "Cross", "Crown", "Deep", "Star", "Mythic"]);
        traits.inclusion = _pickTrait(seed, 3, 100, [uint256(40), 66, 84, 94, 99, 100], ["None", "Vein", "Bubble", "Rutiled", "Core", "Ancient"]);
        traits.clarity = _pickTrait(seed, 4, 100, [uint256(42), 68, 86, 96, 99, 100], ["Clear", "Bright", "Glass", "Prismatic", "Flawless", "Singular"]);
        traits.backgroundName = _pickTrait(seed, 5, 100, [uint256(32), 56, 74, 88, 96, 100], ["Base Grid", "Deep Blue", "Vault", "Signal", "Night", "Abyss"]);
        traits.className = _className(tokenId);
        traits.mythic = uint256(keccak256(abi.encode(seed, "MYTHIC"))) % 100 == 0;
        traits.radiant = uint256(keccak256(abi.encode(seed, "RADIANT"))) % 1000 == 0;
    }

    function _className(uint256 tokenId) internal pure returns (string memory) {
        if (tokenId <= 200) return "Founder Bit";
        if (((tokenId - 1) % 500) < 20) return "Signal Bit";
        return "Standard Bit";
    }

    function _attributesJson(TraitSet memory traits) internal pure returns (string memory) {
        return string.concat(
            "[",
            _trait("Beryl Color", traits.berylColor),
            ",",
            _trait("Cut", traits.cut),
            ",",
            _trait("Facet Pattern", traits.facetPattern),
            ",",
            _trait("Inclusion", traits.inclusion),
            ",",
            _trait("Clarity", traits.clarity),
            ",",
            _trait("Background", traits.backgroundName),
            ",",
            _trait("Class", traits.className),
            ",",
            _trait("Mythic", traits.mythic ? "Yes" : "No"),
            ",",
            _trait("Radiant", traits.radiant ? "Yes" : "No"),
            "]"
        );
    }

    function _trait(string memory traitType, string memory value) internal pure returns (string memory) {
        return string.concat('{"trait_type":"', traitType, '","value":"', value, '"}');
    }

    function _renderSvg(TraitSet memory traits) internal pure returns (string memory) {
        string memory svg = string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="320" viewBox="0 0 320 320" shape-rendering="crispEdges">',
            '<rect width="320" height="320" fill="',
            _backgroundColor(traits.backgroundName),
            '"/>'
        );

        for (uint256 y = 0; y < 16; ++y) {
            for (uint256 x = 0; x < 16; ++x) {
                string memory color = _pixelColor(x, y, traits);
                if (bytes(color).length != 0) svg = string.concat(svg, _px(x, y, color));
            }
        }

        return string.concat(svg, _effects(traits), "</svg>");
    }

    /// @dev Animated overlays for the rare tiers. Mythic adds twinkling sparkles;
    /// Radiant adds a holographic shine sweep on top. Pure pixel/SVG, no text.
    function _effects(TraitSet memory traits) internal pure returns (string memory) {
        if (!traits.mythic && !traits.radiant) return "";

        string memory fx = string.concat(
            '<rect x="180" y="120" width="20" height="20" fill="#ffffff" opacity="0">',
            '<animate attributeName="opacity" values="0;1;0" dur="2s" repeatCount="indefinite"/></rect>',
            '<rect x="120" y="160" width="20" height="20" fill="#fff7d6" opacity="0">',
            '<animate attributeName="opacity" values="0;0.9;0" dur="2.6s" begin="0.7s" repeatCount="indefinite"/></rect>'
        );

        if (traits.radiant) {
            fx = string.concat(
                fx,
                '<g transform="skewX(-18)"><rect x="-60" y="-40" width="34" height="400" fill="#ffffff" opacity="0.16">',
                '<animateTransform attributeName="transform" type="translate" values="0 0;480 0" dur="2.4s" repeatCount="indefinite"/>',
                '</rect></g>'
            );
        }

        return fx;
    }

    function _pickTrait(
        bytes32 seed,
        uint256 salt,
        uint256 denominator,
        uint256[6] memory cutoffs,
        string[6] memory values
    ) internal pure returns (string memory) {
        uint256 roll = uint256(keccak256(abi.encode(seed, salt))) % denominator;
        for (uint256 i = 0; i < cutoffs.length; ++i) {
            if (roll < cutoffs[i]) return values[i];
        }
        return values[values.length - 1];
    }

    function _pixelColor(uint256 x, uint256 y, TraitSet memory traits) internal pure returns (string memory) {
        string memory stone = _crystalPixel(x, y, traits);
        if (bytes(stone).length != 0) return stone;
        return _backgroundPixel(x, y, traits.backgroundName);
    }

    function _crystalPixel(uint256 x, uint256 y, TraitSet memory traits) internal pure returns (string memory) {
        // Centered beryl crystal silhouette. No eyes, face, antenna, aura, markers, or text.
        if (y < 3 || y > 12) return "";
        (uint256 left, uint256 right) = _cutBounds(y, traits.cut);
        if (x < left || x > right) return "";

        string memory edge = traits.radiant ? "#fff0a8" : (traits.mythic ? "#f6b73c" : "#07112d");
        if (x == left || x == right || y == 3 || y == 12) return edge;

        string memory color = _berylColor(traits.berylColor);
        string memory light = _lightColor(traits.clarity);
        string memory shadow = _shadowColor(traits.berylColor);

        if (_inclusionPixel(x, y, traits.inclusion)) return traits.mythic ? "#ffd66e" : "#ffffff";
        if (_facetPixel(x, y, traits.facetPattern)) return light;
        if ((x <= 6 && y >= 6) || (x == 5 && y >= 5)) return shadow;
        if ((x >= 9 && y <= 9) || (x == 10 && y >= 5 && y <= 10)) return light;
        return color;
    }

    /// @dev Per-row crystal silhouette bounds, varied by Cut.
    /// Hex returns the original silhouette unchanged (canonical look); the other
    /// cuts add distinct centered shapes that previously rendered identically.
    function _cutBounds(uint256 y, string memory cut) internal pure returns (uint256 left, uint256 right) {
        bytes32 kind = keccak256(bytes(cut));

        if (kind == keccak256("Prism")) {
            // Beveled vertical column.
            if (y == 3 || y == 12) return (7, 8);
            return (6, 9);
        }
        if (kind == keccak256("Needle")) {
            // Thin tall spire with a small mid bulge.
            if (y == 8 || y == 9) return (6, 9);
            return (7, 8);
        }
        if (kind == keccak256("Royal")) {
            // Wide, full-bodied gem.
            if (y == 3 || y == 12) return (6, 9);
            if (y == 4 || y == 5 || y == 11) return (5, 10);
            return (4, 11);
        }
        if (kind == keccak256("Step")) {
            // Terraced diamond with stepped sides.
            if (y == 3 || y == 4 || y == 11 || y == 12) return (7, 8);
            if (y == 5 || y == 6 || y == 9 || y == 10) return (6, 9);
            return (5, 10);
        }
        if (kind == keccak256("Shard")) {
            // Asymmetric, right-leaning fractured crystal.
            if (y == 3) return (7, 9);
            if (y == 4) return (7, 10);
            if (y == 5) return (6, 10);
            if (y == 6 || y == 7) return (6, 11);
            if (y == 8) return (5, 11);
            if (y == 9) return (5, 10);
            if (y == 10) return (6, 10);
            if (y == 11) return (6, 9);
            return (7, 9); // y == 12
        }

        // Hex (default) — original silhouette, byte-for-byte unchanged.
        left = y <= 7 ? 8 - ((y - 1) / 2) : 4 + ((y - 8) / 2);
        right = y <= 7 ? 7 + ((y - 1) / 2) : 11 - ((y - 8) / 2);
    }

    function _facetPixel(uint256 x, uint256 y, string memory facetPattern) internal pure returns (bool) {
        bytes32 kind = keccak256(bytes(facetPattern));
        if (kind == keccak256("Cross")) return (x == 7 && y >= 5 && y <= 10) || (y == 7 && x >= 5 && x <= 10);
        if (kind == keccak256("Crown")) return (y == 5 && x >= 6 && x <= 9) || (x == 8 && y >= 4 && y <= 8);
        if (kind == keccak256("Deep")) return (x + y == 14 && y >= 5 && y <= 10) || (x == 8 && y >= 6 && y <= 11);
        if (kind == keccak256("Star")) return (x == 8 && y >= 5 && y <= 10) || (x + y == 15 && y >= 5 && y <= 10);
        if (kind == keccak256("Mythic")) return (x == 8 && y >= 4 && y <= 11) || (y == 8 && x >= 5 && x <= 10) || (x + y == 15 && y >= 5 && y <= 10);
        return (x == 8 && y >= 5 && y <= 10) || (x + y == 15 && y >= 6 && y <= 9);
    }

    function _inclusionPixel(uint256 x, uint256 y, string memory inclusion) internal pure returns (bool) {
        bytes32 kind = keccak256(bytes(inclusion));
        if (kind == keccak256("None")) return false;
        if (kind == keccak256("Vein")) return x == 6 && y >= 6 && y <= 10;
        if (kind == keccak256("Bubble")) return (x == 7 && y == 8) || (x == 9 && y == 6);
        if (kind == keccak256("Rutiled")) return (x + y == 13 && y >= 5 && y <= 9);
        if (kind == keccak256("Core")) return (x == 7 || x == 8) && (y == 7 || y == 8);
        if (kind == keccak256("Ancient")) return (x == 8 && y == 6) || (x == 7 && y == 8) || (x == 9 && y == 10);
        return false;
    }

    function _backgroundPixel(uint256 x, uint256 y, string memory backgroundName) internal pure returns (string memory) {
        bytes32 kind = keccak256(bytes(backgroundName));
        if (kind == keccak256("Abyss") && ((x == 1 && y == 1) || (x == 14 && y == 13))) return "#1e2d5e";
        if (kind == keccak256("Signal") && ((y == 2 && x <= 1) || (y == 13 && x >= 14))) return "#17376f";
        if ((x == y && x % 5 == 0) || (x == 2 && y == 12) || (x == 13 && y == 3)) return "#17376f";
        return "";
    }

    function _px(uint256 x, uint256 y, string memory color) internal pure returns (string memory) {
        return string.concat(
            '<rect x="', (x * 20).toString(),
            '" y="', (y * 20).toString(),
            '" width="20" height="20" fill="', color, '"/>'
        );
    }

    function _backgroundColor(string memory backgroundName) internal pure returns (string memory) {
        bytes32 kind = keccak256(bytes(backgroundName));
        if (kind == keccak256("Deep Blue")) return "#0b1d46";
        if (kind == keccak256("Vault")) return "#101c3d";
        if (kind == keccak256("Signal")) return "#0e244f";
        if (kind == keccak256("Night")) return "#081631";
        if (kind == keccak256("Abyss")) return "#040814";
        return "#112a5c";
    }

    function _berylColor(string memory berylColor) internal pure returns (string memory) {
        bytes32 kind = keccak256(bytes(berylColor));
        if (kind == keccak256("Emerald")) return "#24c478";
        if (kind == keccak256("Heliodor")) return "#f0c84b";
        if (kind == keccak256("Morganite")) return "#f3a6b5";
        if (kind == keccak256("Goshenite")) return "#dff7ff";
        if (kind == keccak256("Red Beryl")) return "#d93652";
        return "#55d7ff";
    }

    function _lightColor(string memory clarity) internal pure returns (string memory) {
        bytes32 kind = keccak256(bytes(clarity));
        if (kind == keccak256("Flawless")) return "#ffffff";
        if (kind == keccak256("Singular")) return "#ffe59a";
        if (kind == keccak256("Prismatic")) return "#b8f7ff";
        return "#dff7ff";
    }

    function _shadowColor(string memory berylColor) internal pure returns (string memory) {
        bytes32 kind = keccak256(bytes(berylColor));
        if (kind == keccak256("Emerald")) return "#126139";
        if (kind == keccak256("Heliodor")) return "#9b7a1e";
        if (kind == keccak256("Morganite")) return "#a45a72";
        if (kind == keccak256("Goshenite")) return "#7da6bd";
        if (kind == keccak256("Red Beryl")) return "#7c172b";
        return "#2478a8";
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        if (to == address(0)) revert ZeroAddress();
        if (ownerOf(tokenId) != from) revert NotTokenOwner();
        delete _tokenApprovals[tokenId];
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private returns (bool) {
        if (to.code.length == 0) return true;
        try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
            return retval == IERC721Receiver.onERC721Received.selector;
        } catch {
            return false;
        }
    }
}
