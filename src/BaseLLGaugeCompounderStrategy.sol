// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.28;

import {dYFIHelper} from "./libraries/dYFIHelper.sol";
import {IGauge} from "./interfaces/veyfi/IGauge.sol";
import {IAuction} from "./interfaces/IAuction.sol";

import {Base4626Compounder, ERC20, IStrategy, Math, SafeERC20} from "@periphery/Bases/4626Compounder/Base4626Compounder.sol";
import {UniswapV3Swapper} from "@periphery/swappers/UniswapV3Swapper.sol";

/// @title Base Liquid Locker Gauge Compounder Strategy
/// @notice Abstract base contract for Liquid Locker gauge compounding strategies
/// @dev Inherits Base4626Compounder for vault functionality, and includes UniswapV3 and Auction swapping capabilities
/// @custom:security-contact security@yearn.fi
abstract contract BaseLLGaugeCompounderStrategy is
    UniswapV3Swapper,
    Base4626Compounder
{
    using SafeERC20 for ERC20;

    /// @notice The Wrapped Ether contract address
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @notice The dYFI token contract address
    address public constant DYFI = 0x41252E8691e964f7DE35156B68493bAb6797a275;

    /// @notice Flag to control whether deposits are open to all addresses or restricted to the parent vault
    /// @dev When true, any address can deposit; when false, only the parent vault can deposit
    /// @dev Defaults to false only allowing the parent vault to deposit
    bool public openDeposits;

    /// @notice Flag to keep dYFI rewards instead of converting to WETH
    /// @dev When true, dYFI rewards will remain in the contract
    bool public keepDYfi;

    /// @notice Flag to keep WETH instead of swapping to the strategy's asset
    /// @dev When true, WETH will remain in the contract
    bool public keepWeth;

    /// @notice Flag to enable using auctions for token swaps
    /// @dev When true, uses auction-based swapping mechanism instead of Uniswap
    bool public useAuctions;

    /// @notice Address of the auction contract used for token swaps
    /// @dev Used when useAuctions is true
    address public auction;

    /// @notice Minimum amount of dYFI required to trigger conversion to WETH
    /// @dev Only converts dYFI to WETH if balance is above this threshold
    uint64 public minDYfiToSell;

    /// @notice The Yearn gauge contract this strategy interacts with
    /// @dev Immutable reference to the gauge that provides rewards
    IGauge public immutable Y_GAUGE;

    /// @notice The protocol specific address that holds gauge tokens
    /// @dev Immutable reference to the gauge token holder
    address public immutable Y_GAUGE_SHARE_HOLDER;

    /// @notice The parent allocator vault that distributes funds between LL strategies
    /// @dev This vault is responsible for allocating assets between different LL providers
    address public immutable PARENT_VAULT;

    bytes32 public immutable LOCKER_TYPE_HASH;

    /// @notice Transient flag to control flash loan access
    /// @dev Only enabled during legitimate flash loan operations to prevent unauthorized calls
    bool private transient flashLoanEnabled;

    /// @notice Initializes the strategy with vault parameters and Uniswap settings
    /// @param _yGauge Address of the yearn gauge
    /// @param _lockerName Name of the liquid locker
    /// @param _assetSwapUniFee Uniswap V3 fee tier for asset swaps (use 0 if asset is WETH)
    /// @param _parentVault Address of the parent allocator vault that distributes funds between LL strategies
    /// @dev Sets up Uniswap fee tiers for non-WETH assets
    constructor(
        address _yGauge,
        string memory _lockerName,
        uint24 _assetSwapUniFee,
        address _parentVault,
        address _yGaugeShareHolder
    )
        Base4626Compounder(
            IStrategy(IStrategy(_yGauge).asset()).asset(), // the underlying asset
            string.concat(
                IStrategy(_yGauge).name(),
                " ",
                _lockerName,
                " Compounder"
            ),
            IStrategy(_yGauge).asset() // the vault
        )
    {
        Y_GAUGE = IGauge(_yGauge);
        minAmountToSell = 0.005e18; // minEthToSwap;
        minDYfiToSell = uint64(0.01e18); // 0.01 dYFI default threshold
        if (address(asset) != WETH && _assetSwapUniFee != 0) {
            _setUniFees(WETH, address(asset), _assetSwapUniFee);
        } else {
            keepWeth = true;
        }
        PARENT_VAULT = _parentVault;
        Y_GAUGE_SHARE_HOLDER = _yGaugeShareHolder;
        LOCKER_TYPE_HASH = keccak256(bytes(_lockerName));
    }

    /// @notice Returns the maximum amount of tokens that can be staked in the LL gauge
    /// @dev This function is overridden by child strategy implementations to account for
    ///      limitations specific to different LL gauges.
    ///      Returns max uint256 by default, but child strategies will likely return the
    ///      gauge's maxDeposit value to prevent reverts when staking.
    /// @return The maximum amount of vault tokens that can be staked in the gauge
    function _stakeMaxDeposit() internal view virtual returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc Base4626Compounder
    /// @notice Determines how much an address can deposit based on multiple constraints
    /// @dev This function applies several deposit limit checks in sequence:
    ///      1. Access control: If openDeposits is false and caller isn't PARENT_VAULT, return 0
    ///      2. Gauge capacity: Convert gauge's max deposit to asset amount (_maxStakeInAsset)
    ///      3. Existing idle assets: If we already have enough idle assets, return 0
    ///      4. Available capacity: Return min of (gauge capacity minus idle assets) and parent limit
    ///      This ensures we don't accept deposits we can't stake, while respecting other limits.
    /// @param _owner The address attempting to deposit
    /// @return The maximum amount (in asset terms) that _owner can deposit
    function availableDepositLimit(
        address _owner
    ) public view virtual override returns (uint256) {
        if (!openDeposits && _owner != PARENT_VAULT) return 0;
        // Otherwise, use the standard deposit limit logic from the parent contract
        uint256 _maxStakeInAsset = vault.convertToAssets(_stakeMaxDeposit());
        uint256 _idleAsset = balanceOfAsset();
        if (_maxStakeInAsset <= _idleAsset) return 0;
        return
            Math.min(
                _maxStakeInAsset - _idleAsset,
                super.availableDepositLimit(_owner)
            );
    }
    /// @notice Calculate the maximum amount that can be withdrawn from staked vault shares
    /// @dev Calculates the maximum redeemable amount by taking the minimum of:
    ///      1. The strategy's staked balance
    ///      2. The maximum amount the gauge can redeem from the vault
    ///      3. The maximum amount the gauge share holder can redeem from the gauge
    ///      Then converts this share amount to the equivalent asset amount.
    /// @return The maximum withdrawable amount in terms of the underlying asset
    /// Ignores vault shares since the strategy should never hold raw vault shares
    function vaultsMaxWithdraw() public view override returns (uint256) {
        uint256 _stakeMaxRedeem = Math.min(
            balanceOfStake(),
            Math.min(
                vault.maxRedeem(address(Y_GAUGE)),
                Y_GAUGE.maxRedeem(Y_GAUGE_SHARE_HOLDER)
            )
        );

        return vault.convertToAssets(_stakeMaxRedeem);
    }

    /// @notice Claims dYFI rewards and converts them according to strategy configuration
    /// @dev Override of Base4626Compounder._claimAndSellRewards().
    ///      Follows a multi-step process:
    ///      1. Claims dYFI rewards through the gauge-specific _claimDYfi implementation
    ///      2. If keepDYfi is false AND we have enough dYFI (>= minDYfiToSell), converts dYFI to WETH
    ///      3. If keepWeth is false AND asset isn't WETH AND we have a valid swap fee set, swaps WETH to asset
    ///      This design allows management to control each step of the conversion process based on
    ///      market conditions by toggling flags or adjusting thresholds.
    function _claimAndSellRewards() internal override {
        _claimDYfi();

        uint256 dYfiBalance = ERC20(DYFI).balanceOf(address(this));

        if (!keepDYfi && dYfiBalance >= minDYfiToSell) {
            dYFIHelper.dumpToWeth();
        }

        if (
            !keepWeth &&
            address(asset) != address(WETH) &&
            uniFees[address(WETH)][address(asset)] != 0
        ) {
            _swapFrom(
                address(WETH),
                address(asset),
                ERC20(WETH).balanceOf(address(this)),
                0
            );
        }
    }

    /// @notice Claims dYFI rewards from the gauge
    /// @dev Must be implemented by derived contracts to handle specific gauge claiming logic
    function _claimDYfi() internal virtual;

    /// @notice Callback function for Balancer flash loans used in dYFI redemption
    /// @dev Called by Balancer Vault during flash loan execution as part of the redemption process.
    ///      Security checks:
    ///      1. Ensures caller is the legitimate Balancer Vault
    ///      2. Verifies flash loan has no fees (we only use fee-free flash loans)
    ///      3. Delegates execution to dYFIHelper which has the redemption logic
    ///      This function integrates with Balancer's flash loan system to perform atomic
    ///      redemption of dYFI tokens at optimal rates.
    /// @param . Array of token addresses for the flash loan (unused but required by interface)
    /// @param . Array of amounts for each token (unused but required by interface)
    /// @param feeAmounts Array of fee amounts for each token (must be zero)
    /// @param userData Additional data passed through the flash loan (contains redemption parameters)
    function receiveFlashLoan(
        address[] calldata /*tokens*/,
        uint256[] calldata /*amounts*/,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        require(msg.sender == address(dYFIHelper.BALANCER_VAULT), "!balancer");
        require(flashLoanEnabled, "!enabled"); // Prevent unauthorized flash loan calls
        require(feeAmounts.length == 1 && feeAmounts[0] == 0, "fee");
        flashLoanEnabled = false; // Reset flag immediately after use
        dYFIHelper.flashloanLogic(userData);
    }

    /// @notice Enables flash loan capability for a single transaction
    /// @dev Security control that can only be called by the contract itself
    ///      Acts as a circuit breaker to prevent unauthorized flash loans
    function setFlashLoanEnabled() external {
        require(msg.sender == address(this), "!me");
        flashLoanEnabled = true;
    }

    /// @notice Sets whether deposits are open to all addresses or restricted to the parent vault
    /// @param _openDeposits When true, any address can deposit; when false, only the parent vault can deposit
    /// @dev Can only be called by management
    /// @dev Used to control deposit access
    function setOpenDeposits(bool _openDeposits) external onlyManagement {
        openDeposits = _openDeposits;
    }

    /// @notice Sets whether to keep dYFI rewards instead of converting to WETH
    /// @param _keepDYfi New value for keepDYfi flag
    /// @dev Can only be called by management
    function setKeepDYfi(bool _keepDYfi) external onlyManagement {
        keepDYfi = _keepDYfi;
    }

    /// @notice Sets whether to keep WETH instead of swapping to strategy asset
    /// @param _keepWeth New value for keepWeth flag
    /// @dev Can only be called by management
    function setKeepWeth(bool _keepWeth) external onlyManagement {
        keepWeth = _keepWeth;
    }

    /// @notice Sets whether to use auctions for token swaps
    /// @param _useAuctions New value for useAuctions flag
    /// @dev Can only be called by governance
    function setUseAuctions(bool _useAuctions) external onlyManagement {
        useAuctions = _useAuctions;
    }

    /// @notice Sets the Uniswap V3 fee tier for WETH to asset swaps
    /// @dev Can only be called by management
    /// @param _wethToAssetSwapFee The fee tier to use (in hundredths of a bip)
    function setWethToAssetSwapFee(
        uint24 _wethToAssetSwapFee
    ) external onlyManagement {
        _setUniFees(WETH, address(asset), _wethToAssetSwapFee);
    }

    /// @notice Sets the minimum amount of WETH required to trigger a swap
    /// @dev Can only be called by management
    /// @param _minWethToSwap Minimum amount of WETH tokens (in wei) needed to execute a swap
    function setMinWethToSwap(uint256 _minWethToSwap) external onlyManagement {
        minAmountToSell = _minWethToSwap;
    }

    /// @notice Sets the minimum amount of dYFI required to trigger conversion to WETH
    /// @dev Can only be called by management
    /// @param _minDYfiToSell Minimum amount of dYFI tokens (in wei) needed to execute conversion
    function setMinDYfiToSell(uint64 _minDYfiToSell) external onlyManagement {
        minDYfiToSell = _minDYfiToSell;
    }

    /// @notice Sets the auction contract address
    /// @param _auction Address of the auction contract
    /// @dev Can only be called by management
    /// @dev Verifies the auction contract is compatible with this strategy
    function setAuction(address _auction) external onlyManagement {
        if (_auction != address(0)) {
            require(IAuction(_auction).want() == address(asset), "!want");
            require(
                IAuction(_auction).receiver() == address(this),
                "!receiver"
            );
        }
        auction = _auction;
    }

    /// @notice Initiates an auction for a given token
    /// @dev Can only be called by keepers when auctions are enabled
    /// @param _from The token to be sold in the auction
    /// @return . The available amount for bidding on in the auction.
    function kickAuction(
        address _from
    ) external virtual onlyKeepers returns (uint256) {
        require(useAuctions && auction != address(0), "!auction");
        return _kickAuction(_from);
    }

    /// @notice Internal function to initiate an auction for reward tokens
    /// @dev Transfers tokens to the auction contract and starts the auction process.
    ///      Security features:
    ///      1. Prevents auctioning the strategy's underlying asset or vault tokens
    ///      2. Transfers all available balance of the token to the auction contract
    ///      3. Relies on the auction contract to properly handle the kicked auction
    ///      4. The auction contract has already been validated in setAuction()
    /// @param _from The token to be sold in the auction (e.g., dYFI or WETH)
    /// @return The available amount for bidding on in the auction
    function _kickAuction(address _from) internal virtual returns (uint256) {
        require(_from != address(asset) && _from != address(vault), "!kick");
        address _auction = auction;
        uint256 _balance = ERC20(_from).balanceOf(address(this));
        ERC20(_from).safeTransfer(_auction, _balance);
        return IAuction(_auction).kick(_from);
    }

    /// @dev Required for WETH unwrapping operations
    receive() external payable {}
}
