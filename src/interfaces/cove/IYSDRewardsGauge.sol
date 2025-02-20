pragma solidity ^0.8.18;

interface IYSDRewardsGauge {
    // Custom Errors
    error CannotRedirectForAnotherUser();
    error InvalidDistributorAddress();
    error InvalidInitialization();
    error MaxRewardsReached();
    error MaxTotalAssetsExceeded();
    error RewardAmountTooLow();
    error RewardCannotBeAsset();
    error RewardTokenAlreadyAdded();
    error RewardTokenNotAdded();
    error Unauthorized();
    error ZeroAddress();

    // Structs
    struct Reward {
        address distributor;
        uint256 periodFinish;
        uint256 rate;
        uint256 lastUpdate;
        uint256 integral;
        uint256 leftOver;
    }

    // Events
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Deposit(
        address indexed sender,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    event EIP712DomainChanged();
    event Initialized(uint8 version);
    event Paused(address account);
    event RewardDistributorSet(
        address indexed rewardToken,
        address distributor
    );
    event RewardTokenAdded(address indexed rewardToken, address distributor);
    event RewardTokenDeposited(
        address indexed rewardToken,
        uint256 amount,
        uint256 newRate,
        uint256 timestamp
    );
    event RoleAdminChanged(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed newAdminRole
    );
    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Unpaused(address account);
    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    // View Functions
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function MANAGER_ROLE() external view returns (bytes32);
    function MAX_REWARDS() external view returns (uint256);
    function PAUSER_ROLE() external view returns (bytes32);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
    function asset() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function claimData(address, address) external view returns (uint256);
    function claimableReward(
        address user,
        address rewardToken
    ) external view returns (uint256);
    function claimedReward(
        address addr,
        address token
    ) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function coveYearnStrategy() external view returns (address);
    function decimals() external view returns (uint8);
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
    function getRewardData(
        address rewardToken
    ) external view returns (Reward memory);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function getRoleMember(
        bytes32 role,
        uint256 index
    ) external view returns (address);
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool);
    function maxDeposit(address) external view returns (uint256);
    function maxMint(address) external view returns (uint256);
    function maxRedeem(address owner) external view returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function name() external view returns (string memory);
    function nonces(address owner) external view returns (uint256);
    function paused() external view returns (bool);
    function previewDeposit(uint256 assets) external view returns (uint256);
    function previewMint(uint256 shares) external view returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function previewWithdraw(uint256 assets) external view returns (uint256);
    function rewardIntegralFor(
        address,
        address
    ) external view returns (uint256);
    function rewardTokens(uint256) external view returns (address);
    function rewardsReceiver(address) external view returns (address);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function symbol() external view returns (string memory);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function yearnStakingDelegate() external view returns (address);

    // State Changing Functions
    function addReward(address rewardToken, address distributor) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function claimRewards(address addr, address receiver) external;
    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external returns (bool);
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256);
    function depositRewardToken(address rewardToken, uint256 amount) external;
    function grantRole(bytes32 role, address account) external;
    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external returns (bool);
    function initialize(
        address asset_,
        address ysd_,
        address strategy
    ) external;
    function mint(uint256 shares, address receiver) external returns (uint256);
    function pause() external;
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256);
    function renounceRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function setRewardDistributor(
        address rewardToken,
        address distributor
    ) external;
    function setRewardsReceiver(address receiver) external;
    function setStakingDelegateRewardsReceiver(address receiver) external;
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function unpause() external;
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256);
}
