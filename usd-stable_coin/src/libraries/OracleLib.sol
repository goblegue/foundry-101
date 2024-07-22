//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    error OracleLib__StalePrice();

    function staleCheckLatestRoundData(AggregatorV3Interface chainlinkFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        uint256 TIMEOUT = _getHeartBeat(chainlinkFeed);
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            chainlinkFeed.latestRoundData();

        if (updatedAt == 0 || answeredInRound < roundId) {
            revert OracleLib__StalePrice();
        }
        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) revert OracleLib__StalePrice();

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    function _getHeartBeat(AggregatorV3Interface priceFeed) internal view returns (uint256) {
        uint80 latestRoundId;
        (,,,, latestRoundId) = priceFeed.latestRoundData();

        uint256 totalInterval = 0;
        uint80 currentRoundId = latestRoundId;

        for (uint80 i = 0; i < 1; i++) {
            (,,, uint256 updatedAt,) = priceFeed.getRoundData(currentRoundId);
            (,,, uint256 prevUpdatedAt,) = priceFeed.getRoundData(currentRoundId - 1);

            totalInterval += (updatedAt - prevUpdatedAt);
            currentRoundId -= 1;
        }

        return totalInterval / 1;
    }
}
