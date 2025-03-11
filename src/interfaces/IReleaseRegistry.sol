// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

interface IReleaseRegistry {
    event GovernanceTransferred(
        address indexed previousGovernance,
        address indexed newGovernance
    );
    event NewRelease(
        uint256 indexed releaseId,
        address indexed factory,
        address indexed tokenizedStrategy,
        string apiVersion
    );
    event UpdatePendingGovernance(address indexed newPendingGovernance);
    function acceptGovernance() external;
    function factories(uint256) external view returns (address);
    function governance() external view returns (address);
    function latestFactory() external view returns (address);
    function latestRelease() external view returns (string memory);
    function latestTokenizedStrategy() external view returns (address);
    function name() external view returns (string memory);
    function newRelease(address _factory, address _tokenizedStrategy) external;
    function numReleases() external view returns (uint256);
    function pendingGovernance() external view returns (address);
    function releaseTargets(string calldata) external view returns (uint256);
    function tokenizedStrategies(uint256) external view returns (address);
    function transferGovernance(address _newGovernance) external;
}
