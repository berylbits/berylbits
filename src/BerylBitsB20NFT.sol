// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract BerylBitsB20NFT is ERC721, AccessControl {
    using Strings for uint256;

    bytes32 public constant FORGE_ROLE = keccak256("FORGE_ROLE");

    uint256 public constant MAX_SHARED_UNITS = 10_000;

    struct TraitSet {
        string core;
        string shell;
        string eyes;
        string aura;
        string antenna;
        string backgroundName;
        string className;
        bool mythic;
    }

    uint256 public totalMinted;
    uint256 public liveSupply;
    mapping(uint256 => bytes32) public tokenSeed;

    error SupplyExceeded();
    error NotTokenOwner();

    constructor(address admin) ERC721("Beryl Bits", "BBITS-NFT") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function mintFromForge(address to, uint256 quantity) external onlyRole(FORGE_ROLE) returns (uint256 firstTokenId) {
        if (liveSupply + quantity > MAX_SHARED_UNITS) revert SupplyExceeded();

        firstTokenId = totalMinted + 1;
        for (uint256 i = 0; i < quantity; ++i) {
            uint256 tokenId = totalMinted + 1;
            totalMinted = tokenId;
            liveSupply += 1;
            tokenSeed[tokenId] = keccak256(abi.encode(to, tokenId, block.prevrandao, blockhash(block.number - 1)));
            _safeMint(to, tokenId);
        }
    }

    function burnFromForge(address owner, uint256 tokenId) external onlyRole(FORGE_ROLE) {
        if (ownerOf(tokenId) != owner) revert NotTokenOwner();
        _burn(tokenId);
        liveSupply -= 1;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        TraitSet memory traits = traitSet(tokenId);

        string memory name = string.concat("Beryl Bit #", tokenId.toString());
        string memory image = Base64.encode(bytes(_renderSvg(traits)));
        string memory json = Base64.encode(
            bytes(
                string.concat(
                    '{"name":"',
                    name,
                    '","description":"Beryl Bits are Base-native 8-bit relics forged from a shared B20 supply.",',
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
        _requireOwned(tokenId);
        return _renderSvg(traitSet(tokenId));
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function traitSet(uint256 tokenId) public view returns (TraitSet memory traits) {
        bytes32 seed = tokenSeed[tokenId];

        traits.core = _pickTrait(seed, 0, 100, [uint256(40), 64, 80, 90, 96, 100], ["Blue", "Cyan", "White", "Plasma", "Void", "Amber"]);
        traits.shell = _pickTrait(seed, 1, 100, [uint256(28), 52, 70, 84, 94, 100], ["Smooth", "Riveted", "Crystal", "Armor", "Glitch", "Mythic"]);
        traits.eyes = _pickTrait(seed, 2, 100, [uint256(26), 48, 66, 80, 92, 100], ["Dot", "Wide", "Scanner", "Sleepy", "Split", "Oracle"]);
        traits.aura = _pickTrait(seed, 3, 100, [uint256(34), 58, 76, 88, 96, 100], ["None", "Spark", "Ring", "Pulse", "Burst", "Halo"]);
        traits.antenna = _pickTrait(seed, 4, 100, [uint256(32), 56, 74, 88, 96, 100], ["None", "Stub", "Twin", "Arc", "Crown", "Beacon"]);
        traits.backgroundName = _pickTrait(seed, 5, 100, [uint256(32), 56, 74, 86, 95, 100], ["Grid", "Node", "Chain", "Vault", "Signal", "Abyss"]);

        traits.className = _className(tokenId);
        traits.mythic = uint256(keccak256(abi.encode(seed, "MYTHIC"))) % 100 == 0;
    }

    function _className(uint256 tokenId) internal pure returns (string memory) {
        if (tokenId <= 200) return "Founder Bit";
        if (((tokenId - 1) % 500) < 20) return "Signal Bit";
        return "Standard Bit";
    }

    function _attributesJson(TraitSet memory traits) internal pure returns (string memory) {
        return string.concat(
            "[",
            _trait("Core", traits.core),
            ",",
            _trait("Shell", traits.shell),
            ",",
            _trait("Eyes", traits.eyes),
            ",",
            _trait("Aura", traits.aura),
            ",",
            _trait("Antenna", traits.antenna),
            ",",
            _trait("Background", traits.backgroundName),
            ",",
            _trait("Class", traits.className),
            ",",
            _trait("Mythic", traits.mythic ? "Yes" : "No"),
            "]"
        );
    }

    function _trait(string memory traitType, string memory value) internal pure returns (string memory) {
        return string.concat('{"trait_type":"', traitType, '","value":"', value, '"}');
    }

    function _renderSvg(TraitSet memory traits) internal pure returns (string memory) {
        string memory backgroundColor = _backgroundColor(traits.backgroundName);
        string memory coreColor = _coreColor(traits.core);
        string memory shellColor = _shellColor(traits.shell);
        string memory accentColor = traits.mythic ? "#f6b73c" : "#9be7ff";

        string memory svg = string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="320" viewBox="0 0 320 320" shape-rendering="crispEdges">',
            '<rect width="320" height="320" fill="',
            backgroundColor,
            '"/>'
        );

        for (uint256 y = 0; y < 16; ++y) {
            for (uint256 x = 0; x < 16; ++x) {
                string memory color = _pixelColor(x, y, traits, shellColor, coreColor, accentColor);
                if (bytes(color).length != 0) svg = string.concat(svg, _px(x, y, color));
            }
        }

        return string.concat(svg, "</svg>");
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

    function _pixelColor(
        uint256 x,
        uint256 y,
        TraitSet memory traits,
        string memory shellColor,
        string memory coreColor,
        string memory accentColor
    ) internal pure returns (string memory) {
        string memory antenna = _antennaPixel(x, y, traits.antenna, accentColor);
        if (bytes(antenna).length != 0) return antenna;

        string memory aura = _auraPixel(x, y, traits.aura, accentColor);
        if (bytes(aura).length != 0) return aura;

        string memory stone = _stonePixel(x, y, traits, shellColor, coreColor, accentColor);
        if (bytes(stone).length != 0) return stone;

        string memory marker = _markerPixel(x, y, traits.className, traits.mythic, accentColor);
        if (bytes(marker).length != 0) return marker;

        return _backgroundPixel(x, y, traits.backgroundName);
    }

    function _stonePixel(
        uint256 x,
        uint256 y,
        TraitSet memory traits,
        string memory shellColor,
        string memory coreColor,
        string memory accentColor
    ) internal pure returns (string memory) {
        if (y < 2 || y > 10) return "";
        uint256 left = y <= 5 ? 8 - y : y - 3;
        uint256 right = 15 - left;
        if (x < left || x > right) return "";
        if (x == left || x == right || y == 10) return "#0c1023";
        if (y == 2) return accentColor;

        string memory eye = _eyePixel(x, y, traits.eyes);
        if (bytes(eye).length != 0) return eye;

        string memory facet = _facetPixel(x, y, traits.shell, accentColor);
        if (bytes(facet).length != 0) return facet;

        if ((x >= 6 && x <= 9 && y >= 3 && y <= 9) || (x >= 5 && x <= 10 && y >= 4 && y <= 8)) return coreColor;
        return shellColor;
    }

    function _eyePixel(uint256 x, uint256 y, string memory eyes) internal pure returns (string memory) {
        bytes32 kind = keccak256(bytes(eyes));
        if (kind == keccak256("Wide")) {
            if ((x == 6 || x == 9) && (y == 6 || y == 7)) return "#ffffff";
        }
        if (kind == keccak256("Scanner")) {
            if (x >= 6 && x <= 9 && y == 6) return "#d7ebff";
        }
        if (kind == keccak256("Sleepy")) {
            if ((x == 6 || x == 9) && y == 7) return "#ffffff";
        }
        if (kind == keccak256("Split")) {
            if ((x == 6 || x == 9) && (y == 6 || y == 7)) return "#ffffff";
        }
        if (kind == keccak256("Oracle")) {
            if ((x == 7 || x == 8) && (y == 6 || y == 7)) return "#f6b73c";
        }
        if ((x == 6 || x == 9) && y == 6) return "#ffffff";
        return "";
    }

    function _facetPixel(uint256 x, uint256 y, string memory shell, string memory accentColor) internal pure returns (string memory) {
        bytes32 kind = keccak256(bytes(shell));
        if (kind == keccak256("Crystal") && ((x == 5 && y == 5) || (x == 10 && y == 5) || ((x == 7 || x == 8) && y == 8))) return "#ffffff";
        if (kind == keccak256("Armor") && ((x == 4 && y == 6) || (x == 11 && y == 6) || (x == 5 && y == 8) || (x == 10 && y == 8))) return "#172142";
        if (kind == keccak256("Glitch") && ((x == 4 && y == 4) || (x == 11 && y == 8) || (x == 9 && y == 9))) return "#65ffcb";
        if (kind == keccak256("Mythic") && ((x == 6 && y == 3) || (x == 9 && y == 3) || (x == 7 && y == 5))) return accentColor;
        if (kind == keccak256("Riveted") && ((x == 4 && y == 5) || (x == 11 && y == 5) || (x == 6 && y == 9))) return accentColor;
        return "";
    }

    function _antennaPixel(uint256 x, uint256 y, string memory antenna, string memory accentColor) internal pure returns (string memory) {
        bytes32 kind = keccak256(bytes(antenna));
        if (kind == keccak256("Stub")) {
            if (x == 8 && y == 1) return accentColor;
        }
        if (kind == keccak256("Twin")) {
            if ((x == 6 || x == 9) && y == 1) return accentColor;
        }
        if (kind == keccak256("Arc")) {
            if (((x == 7 || x == 8) && y == 0) || ((x == 6 || x == 9) && y == 1)) return accentColor;
        }
        if (kind == keccak256("Crown")) {
            if ((x == 7 && y == 0) || (x == 10 && y == 0) || (x == 5 && y == 1) || (x == 8 && y == 1)) return accentColor;
        }
        if (kind == keccak256("Beacon")) {
            if ((x == 7 || x == 8) && y == 0) return "#ffffff";
            if (x == 8 && y == 1) return accentColor;
        }
        return "";
    }

    function _auraPixel(uint256 x, uint256 y, string memory aura, string memory accentColor) internal pure returns (string memory) {
        bytes32 kind = keccak256(bytes(aura));
        if (kind == keccak256("Spark")) {
            if ((x == 2 && y == 5) || (x == 13 && y == 9) || (x == 4 && y == 12)) return accentColor;
        }
        if (kind == keccak256("Ring")) {
            if (((x == 5 || x == 10) && (y == 2 || y == 12)) || ((x == 3 || x == 12) && (y == 5 || y == 9))) return accentColor;
        }
        if (kind == keccak256("Pulse")) {
            if ((y == 7) && (x == 1 || x == 2 || x == 13 || x == 14)) return accentColor;
        }
        if (kind == keccak256("Burst")) {
            if ((x == 8 && (y == 0 || y == 14)) || ((x == 2 || x == 13) && (y == 4 || y == 11))) return accentColor;
        }
        if (kind == keccak256("Halo")) {
            if (x >= 6 && x <= 9 && y == 1) return accentColor;
        }
        return "";
    }

    function _markerPixel(uint256 x, uint256 y, string memory className, bool mythic, string memory accentColor) internal pure returns (string memory) {
        if (mythic && ((x == 14 && y == 1) || (x == 15 && y == 1) || (x == 14 && y == 2))) return "#f6b73c";
        bytes32 kind = keccak256(bytes(className));
        if (kind == keccak256("Founder Bit") && ((x == 0 && y == 14) || (x == 1 && y == 14) || (x == 0 && y == 15))) return accentColor;
        if (kind == keccak256("Signal Bit") && ((x == 15 && y == 14) || (x == 14 && y == 15) || (x == 15 && y == 15))) return accentColor;
        return "";
    }

    function _backgroundPixel(uint256 x, uint256 y, string memory backgroundName) internal pure returns (string memory) {
        bytes32 kind = keccak256(bytes(backgroundName));
        if (kind == keccak256("Abyss") && ((x == 1 && y == 1) || (x == 3 && y == 3) || (x == 12 && y == 2) || (x == 14 && y == 12))) return "#23305e";
        if (kind == keccak256("Signal") && ((y == 4 && x <= 1) || (y == 11 && x >= 14) || (x == 4 && y == 0) || (x == 11 && y == 15))) return "#17376f";
        if ((x == y && x % 4 == 0) || (x == 2 && y == 11) || (x == 13 && y == 3)) return "#17376f";
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
        if (kind == keccak256("Node")) return "#0b1d46";
        if (kind == keccak256("Chain")) return "#081631";
        if (kind == keccak256("Vault")) return "#101c3d";
        if (kind == keccak256("Signal")) return "#0e244f";
        if (kind == keccak256("Abyss")) return "#040814";
        return "#112a5c";
    }

    function _coreColor(string memory core) internal pure returns (string memory) {
        bytes32 kind = keccak256(bytes(core));
        if (kind == keccak256("Cyan")) return "#7de5ff";
        if (kind == keccak256("White")) return "#ffffff";
        if (kind == keccak256("Plasma")) return "#8e7bff";
        if (kind == keccak256("Void")) return "#0f132a";
        if (kind == keccak256("Amber")) return "#f6b73c";
        return "#3c7dff";
    }

    function _shellColor(string memory shell) internal pure returns (string memory) {
        bytes32 kind = keccak256(bytes(shell));
        if (kind == keccak256("Riveted")) return "#254a97";
        if (kind == keccak256("Crystal")) return "#6ec1ff";
        if (kind == keccak256("Armor")) return "#1f2f62";
        if (kind == keccak256("Glitch")) return "#3651b5";
        if (kind == keccak256("Mythic")) return "#314e86";
        return "#2b5db8";
    }
}
