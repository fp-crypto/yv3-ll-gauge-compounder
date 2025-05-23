// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

interface AggregatorV3Interface {
    event AnswerUpdated(
        int256 indexed current,
        uint256 indexed roundId,
        uint256 updatedAt
    );
    event NewRound(
        uint256 indexed roundId,
        address indexed startedBy,
        uint256 startedAt
    );
    event OwnershipTransferRequested(address indexed from, address indexed to);
    event OwnershipTransferred(address indexed from, address indexed to);
    function acceptOwnership() external;
    function accessController() external view returns (address);
    function aggregator() external view returns (address);
    function confirmAggregator(address _aggregator) external;
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function getAnswer(uint256 _roundId) external view returns (int256);
    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
    function getTimestamp(uint256 _roundId) external view returns (uint256);
    function latestAnswer() external view returns (int256);
    function latestRound() external view returns (uint256);
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
    function latestTimestamp() external view returns (uint256);
    function owner() external view returns (address);
    function phaseAggregators(uint16) external view returns (address);
    function phaseId() external view returns (uint16);
    function proposeAggregator(address _aggregator) external;
    function proposedAggregator() external view returns (address);
    function proposedGetRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
    function proposedLatestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
    function setController(address _accessController) external;
    function transferOwnership(address _to) external;
    function version() external view returns (uint256);
}
