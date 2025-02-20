// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.18;

interface IGauge {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event BoostedBalanceUpdated(address indexed account, uint256 amount);
    event Deposit(
        address indexed caller,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    event Initialize(address indexed asset, address indexed owner);
    event Initialized(uint8 version);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event RecipientUpdated(address indexed account, address indexed recipient);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsAdded(
        uint256 currentRewards,
        uint256 lastUpdateTime,
        uint256 periodFinish,
        uint256 rewardRate,
        uint256 historicalRewards
    );
    event RewardsQueued(address indexed from, uint256 amount);
    event Sweep(address indexed token, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event TransferredPenalty(address indexed account, uint256 transfered);
    event UpdatedRewards(
        address indexed account,
        uint256 rewardPerTokenStored,
        uint256 lastUpdateTime,
        uint256 rewards,
        uint256 userRewardPerTokenPaid
    );
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    function BOOSTING_FACTOR() external view returns (uint256);
    function BOOST_DENOMINATOR() external view returns (uint256);
    function PRECISION_FACTOR() external view returns (uint256);
    function REWARD_TOKEN() external view returns (address);
    function VEYFI() external view returns (address);
    function VE_YFI_POOL() external view returns (address);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function asset() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function boostedBalanceOf(address _account) external view returns (uint256);
    function controller() external view returns (address);
    function convertToAssets(uint256 _shares) external view returns (uint256);
    function convertToShares(uint256 _assets) external view returns (uint256);
    function decimals() external view returns (uint8);
    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external returns (bool);
    function deposit(
        uint256 _assets,
        address _receiver
    ) external returns (uint256);
    function deposit(uint256 _assets) external returns (uint256);
    function deposit() external returns (uint256);
    function earned(address _account) external view returns (uint256);
    function getReward() external returns (bool);
    function getReward(address _account) external returns (bool);
    function historicalRewards() external view returns (uint256);
    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external returns (bool);
    function initialize(
        address _asset,
        address _owner,
        address _controller,
        bytes memory _data
    ) external;
    function kick(address[] memory _accounts) external;
    function lastTimeRewardApplicable() external view returns (uint256);
    function lastUpdateTime() external view returns (uint256);
    function maxDeposit(address) external view returns (uint256);
    function maxMint(address) external view returns (uint256);
    function maxRedeem(address _owner) external view returns (uint256);
    function maxWithdraw(address _owner) external view returns (uint256);
    function mint(
        uint256 _shares,
        address _receiver
    ) external returns (uint256);
    function name() external view returns (string memory);
    function nextBoostedBalanceOf(
        address _account
    ) external view returns (uint256);
    function owner() external view returns (address);
    function periodFinish() external view returns (uint256);
    function previewDeposit(uint256 _assets) external view returns (uint256);
    function previewMint(uint256 _shares) external view returns (uint256);
    function previewRedeem(uint256 _assets) external view returns (uint256);
    function previewWithdraw(uint256 _assets) external view returns (uint256);
    function recipients(address) external view returns (address);
    function redeem(
        uint256 _assets,
        address _receiver,
        address _owner
    ) external returns (uint256);
    function renounceOwnership() external;
    function rewardPerToken() external view returns (uint256);
    function rewardPerTokenStored() external view returns (uint256);
    function rewardRate() external view returns (uint256);
    function rewards(address) external view returns (uint256);
    function setController(address _newController) external;
    function setRecipient(address _recipient) external;
    function sweep(address _token) external returns (bool);
    function symbol() external view returns (string memory);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function transferOwnership(address newOwner) external;
    function userRewardPerTokenPaid(address) external view returns (uint256);
    function withdraw() external returns (uint256);
    function withdraw(bool _claim) external returns (uint256);
    function withdraw(
        uint256 _assets,
        address _receiver,
        address _owner
    ) external returns (uint256);
    function withdraw(
        uint256 _assets,
        address _receiver,
        address _owner,
        bool _claim
    ) external returns (uint256);
}
