// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.6;

import "@openzeppelin-contracts/utils/Strings.sol";
import "@openzeppelin-contracts/utils/Base64.sol";

/// @title NFTSVG
/// @notice Provides a function for generating an SVG associated with a Uniswap NFT
library NFTSVG {
    using Strings for uint256;

    struct SVGParams {
        string debtorId;
        uint256 tokenId;
    }

    function generateSVG(
        SVGParams memory params
    ) internal pure returns (string memory svg) {
        return
            string(
                abi.encodePacked(
                    generateSVGDefs(),
                    generateSVGContent(params)
                )
            );
    }
    function generateSVGDefs() private pure returns (string memory svg) {
        svg = string(
            abi.encodePacked(
                '<svg width="857" height="500" viewBox="0 0 857 500" fill="none" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">',
                '<defs>',
                '    <symbol id="logo" viewBox="0 0 400 650"> <g> <path d="M279.5 158.5C219.9 116.1 216 44.8333 221.5 14.5C170.72 83.0986 165.269 153.277 216 221C267.317 289.504 301.413 299.457 325.5 388C343.944 455.8 303.569 509.931 287.5 536C303.461 525.702 338.947 510.447 377.5 462.5C469.051 348.643 376.401 227.437 279.5 158.5Z" /> <path d="M253.5 546.5C294 502 309.227 462.471 307.5 411C305.307 345.647 244.985 289.803 205 243.5C136.171 168.699 145.309 70.1467 205 2C84.1916 42.064 -52.821 173.015 53 300C87 340.8 123.333 381.167 138 395C149 405.333 174.8 437.6 190 484C205.2 530.4 179.333 597 164.5 624.5C180.667 613.333 221.1 582.1 253.5 546.5Z" /> <path d="M55.5 340C43.5 326.4 27.1667 301.333 20.5 290.5C-6.51042 345.164 -10.6972 446.478 46 486.5C94.6814 520.863 130.932 556.413 145 615.5C150 605 161.6 578.9 168 558.5C197.47 464.565 110.251 402.051 55.5 340Z" /> </g> </symbol>',
                '    <symbol id="raila-logo" viewBox="0 0 185.764 67.223"> <g> <path d="M 7.917 66.667 L 0 66.667 L 0 4.167 L 15.694 4.167 A 24.735 24.735 0 0 1 20.54 4.619 A 18.057 18.057 0 0 1 25.833 6.528 A 18.107 18.107 0 0 1 30.524 10.218 A 16.533 16.533 0 0 1 32.396 12.743 A 16.024 16.024 0 0 1 34.722 21.181 Q 34.722 26.319 31.806 30.417 A 16.755 16.755 0 0 1 24.77 36.066 A 20.536 20.536 0 0 1 23.819 36.458 L 44.792 66.667 L 35.556 66.667 L 15.694 37.917 L 7.917 37.917 L 7.917 66.667 Z M 84.375 30.486 L 84.375 25 L 91.319 25 L 91.319 66.667 L 84.375 66.667 L 84.375 61.181 Q 81.597 63.958 77.813 65.59 A 20.212 20.212 0 0 1 69.722 67.222 A 19.611 19.611 0 0 1 59.306 64.34 Q 54.583 61.458 51.771 56.597 Q 48.958 51.736 48.958 45.833 Q 48.958 39.931 51.771 35.069 Q 54.583 30.208 59.306 27.326 A 19.611 19.611 0 0 1 69.722 24.444 A 20.592 20.592 0 0 1 77.813 26.042 Q 81.597 27.639 84.375 30.486 Z M 178.819 30.486 L 178.819 25 L 185.764 25 L 185.764 66.667 L 178.819 66.667 L 178.819 61.181 Q 176.042 63.958 172.257 65.59 A 20.212 20.212 0 0 1 164.167 67.222 A 19.611 19.611 0 0 1 153.75 64.34 Q 149.028 61.458 146.215 56.597 Q 143.403 51.736 143.403 45.833 Q 143.403 39.931 146.215 35.069 Q 149.028 30.208 153.75 27.326 A 19.611 19.611 0 0 1 164.167 24.444 A 20.592 20.592 0 0 1 172.257 26.042 Q 176.042 27.639 178.819 30.486 Z M 132.986 66.667 L 125.486 66.667 L 125.486 0 L 132.986 0 L 132.986 66.667 Z M 112.153 66.667 L 104.653 66.667 L 104.653 25 L 112.153 25 L 112.153 66.667 Z M 70.694 60.417 A 13.483 13.483 0 0 0 77.882 58.438 A 14.775 14.775 0 0 0 83.021 53.16 Q 84.931 49.861 84.931 45.833 A 14.641 14.641 0 0 0 83.834 40.147 A 14.058 14.058 0 0 0 83.021 38.507 Q 81.111 35.208 77.882 33.229 A 13.483 13.483 0 0 0 70.694 31.25 A 13.483 13.483 0 0 0 63.507 33.229 A 14.775 14.775 0 0 0 58.368 38.507 Q 56.458 41.806 56.458 45.833 A 14.641 14.641 0 0 0 57.555 51.519 A 14.058 14.058 0 0 0 58.368 53.16 Q 60.278 56.458 63.507 58.438 A 13.483 13.483 0 0 0 70.694 60.417 Z M 165.139 60.417 A 13.483 13.483 0 0 0 172.326 58.438 A 14.775 14.775 0 0 0 177.465 53.16 Q 179.375 49.861 179.375 45.833 A 14.641 14.641 0 0 0 178.278 40.147 A 14.058 14.058 0 0 0 177.465 38.507 Q 175.556 35.208 172.326 33.229 A 13.483 13.483 0 0 0 165.139 31.25 A 13.483 13.483 0 0 0 157.951 33.229 A 14.775 14.775 0 0 0 152.812 38.507 Q 150.903 41.806 150.903 45.833 A 14.641 14.641 0 0 0 151.999 51.519 A 14.058 14.058 0 0 0 152.812 53.16 Q 154.722 56.458 157.951 58.438 A 13.483 13.483 0 0 0 165.139 60.417 Z M 7.917 11.25 L 7.917 31.25 L 15.694 31.25 A 17.813 17.813 0 0 0 18.397 31.057 Q 20.633 30.713 22.257 29.757 Q 24.792 28.264 26.007 25.938 A 10.611 10.611 0 0 0 27.079 22.839 A 9.634 9.634 0 0 0 27.222 21.181 A 9.855 9.855 0 0 0 26.551 17.487 A 9.056 9.056 0 0 0 24.062 14.028 A 10.816 10.816 0 0 0 19.243 11.625 A 15.893 15.893 0 0 0 15.694 11.25 L 7.917 11.25 Z M 104.907 16.087 A 4.817 4.817 0 0 0 108.403 17.5 A 6.256 6.256 0 0 0 108.537 17.499 A 4.765 4.765 0 0 0 111.979 16.042 A 5.009 5.009 0 0 0 112.927 14.7 A 5.036 5.036 0 0 0 113.403 12.5 Q 113.403 10.347 111.979 8.924 A 4.716 4.716 0 0 0 110.254 7.81 A 5.339 5.339 0 0 0 108.403 7.5 A 4.882 4.882 0 0 0 104.861 8.924 Q 103.403 10.347 103.403 12.5 A 5.912 5.912 0 0 0 103.403 12.565 A 4.815 4.815 0 0 0 104.861 16.042 A 5.739 5.739 0 0 0 104.907 16.087 Z" vector-effect="non-scaling-stroke" /> </g> </symbol>',
                '    <linearGradient id="grad" gradientTransform="rotate(20)"> <stop offset="50%" stop-color="#b95632" /> <stop offset="100%" stop-color="#8f4625" /> </linearGradient>',
                '    <linearGradient id="curve-grad" gradientTransform="rotate(0)"> <stop offset="0%" stop-color="#48ff00" /> <stop offset="100%" stop-color="#e70000" /> </linearGradient>',
                '    <symbol id="curve" viewBox="0 0 252 214"> <path d="M4 205C116 205 247 105 247 0" /> </symbol>',
                '    <clipPath id="rect-clip"> <rect x="5" y="5" width="847" height="490" rx="40" ry="30" /> </clipPath>',
                '    <filter id="dropshadow" height="130%"> <feGaussianBlur in="SourceAlpha" stdDeviation="3" /> <feOffset dx="10" dy="10" result="offsetblur" /> <feComponentTransfer> <feFuncA type="linear" slope="1" /> </feComponentTransfer> <feMerge> <feMergeNode /> <feMergeNode in="SourceGraphic" /></feMerge> </filter>',
                '    <filter id="dropshadow2" height="130%"> <feGaussianBlur in="SourceAlpha" stdDeviation="1" /> <feOffset dx="3" dy="3" result="offsetblur" /> <feComponentTransfer> <feFuncA type="linear" slope="0.6" /> </feComponentTransfer> <feMerge> <feMergeNode /> <feMergeNode in="SourceGraphic" /> </feMerge> </filter>',
                ' </defs>'
            )
        );
    }

    function generateSVGContent(
        SVGParams memory params
    ) private pure returns (string memory svg) {
        svg = string(
            abi.encodePacked(
                '<rect x="5" y="5" width="847" height="490" rx="40" ry="30" fill="url(#grad)" stroke="black" stroke-width="1" />',
                '<g clip-path="url(#rect-clip)"> <g filter="url(#dropshadow)"> <use href="#logo" x="-600" y="-50" width="1500" height="800" style="fill: red; opacity: 0.15;" /> </g> </g>',
                '<svg viewBox="0 0 200 100" width="240" x="615" y="-185" style="fill: #ffcc14; opacity: 0.8;"> <g filter="url(#dropshadow2)"> <use href="#raila-logo" x="0" y="0" width="110" /> <use href="#logo" x="75" y="16" width="140" height="70" /> </g> </svg>',
                '<text x="50" y="435" style="font: 14px sans-serif; fill: #ffcc14;">TOKEN</text>',
                '<text id="debtor" x="133" y="435" style="font: 18px sans-serif; fill: #ffcc14; text-shadow: 1px 1px 1px #1c1c1c; opacity: 0.9;">',
                Strings.toString(params.tokenId),
                '</text> <text x="50" y="465" style="font: 14px sans-serif; fill: #ffcc14;">DEBTOR ID</text>',
                '<text id="debtor" x="133" y="465" style="text-transform: uppercase; font: 18px sans-serif; fill: #ffcc14; text-shadow: 1px 1px 1px #1c1c1c; opacity: 0.9;">',
                params.debtorId,
                '</text> </svg>'
            )
        );
    }
}
