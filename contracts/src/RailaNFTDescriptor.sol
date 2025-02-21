// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.0;
pragma abicoder v2;

import "@openzeppelin-contracts/utils/Strings.sol";
import "@openzeppelin-contracts/utils/Base64.sol";
import "./NFTSVG.sol";
import "./Raila.sol";

library HexStrings {
    bytes16 internal constant ALPHABET = "0123456789abcdef";

    /// @notice Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
    /// @dev Credit to Open Zeppelin under MIT license https://github.com/OpenZeppelin/openzeppelin-contracts/blob/243adff49ce1700e0ecb99fe522fb16cff1d1ddc/contracts/utils/Strings.sol#L55
    function toHexString(
        uint256 value,
        uint256 length
    ) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = ALPHABET[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    function toHexStringNoPrefix(
        uint256 value,
        uint256 length
    ) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length);
        for (uint256 i = buffer.length; i > 0; i--) {
            buffer[i - 1] = ALPHABET[value & 0xf];
            value >>= 4;
        }
        return string(buffer);
    }
}

contract RailaNFTDescriptor {
    using HexStrings for uint256;

    Raila immutable RAILA;

    constructor(Raila raila) {
        RAILA = raila;
    }

    function constructTokenURI(
        uint256 tokenId
    ) public view returns (string memory) {
        (bytes20 debtorId, , , , , , uint16 fee, , , , ) = RAILA.requests(
            tokenId
        );

        string memory description = generateDescription(
            addressToString(address(debtorId)),
            fee
        );
        string memory image = Base64.encode(
            bytes(generateSVGImage(debtorId, tokenId))
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name": "Raila Loan", "description":"',
                                description,
                                '", "image": "',
                                "data:image/svg+xml;base64,",
                                image,
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    function generateDescription(
        string memory debtorId,
        uint24 fee
    ) private pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "This NFT represents an uncollateralized loan in Raila.",
                    " The owner of this NFT is the creditor, and is entitled to receive the funds pending payment",
                    " plus additional interest, is able to transfer the creditor status, and able to forgive the debt.\\n",
                    " The debtor of this loan is the human with humanityId: ",
                    debtorId,
                    ".\\n Failing to pay the debt in time, such that the debt exceeds the default threshold,"
                    " will include the debtor, as a human, in a list of known defaulters.",
                    " Raila protocol fee at ",
                    Strings.toString(fee / 100),
                    "% of realized interest."
                )
            );
    }

    function addressToString(
        address addr
    ) internal pure returns (string memory) {
        return (uint256(uint160(addr))).toHexString(20);
    }

    function addressToStringCreditCardStyle(
        address addr
    ) internal pure returns (string memory) {
        string memory fullHex = (uint256(uint160(addr))).toHexString(20);
        bytes memory noPrefix = new bytes(49);
        uint256 spaces = 0;
        for (uint i = 0; i < 40; i++) {
            noPrefix[i + spaces] = bytes(fullHex)[i + 2];
            if (i % 4 == 3 && i != 39) {
                spaces++;
                noPrefix[i + spaces] = " ";
            }
        }
        return string(noPrefix);
    }

    function generateSVGImage(
        bytes20 debtorId,
        uint256 tokenId
    ) internal pure returns (string memory svg) {
        NFTSVG.SVGParams memory svgParams = NFTSVG.SVGParams({
            debtorId: addressToStringCreditCardStyle(address(debtorId)),
            tokenId: tokenId
        });

        return NFTSVG.generateSVG(svgParams);
        // return "";
    }
}
