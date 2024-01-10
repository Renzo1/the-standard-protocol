// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol" as Chainlink;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/interfaces/IEUROs.sol";
import "contracts/interfaces/ILiquidationPool.sol";
import "contracts/interfaces/ILiquidationPoolManager.sol";
import "contracts/interfaces/ISmartVaultManager.sol";
import "contracts/interfaces/ITokenManager.sol";

contract LiquidationPool is ILiquidationPool {
    using SafeERC20 for IERC20;

    address private immutable TST;
    address private immutable EUROs;
    address private immutable eurUsd;

    address[] public holders;
    mapping(address => Position) private positions;
    mapping(bytes => uint256) private rewards;
    PendingStake[] private pendingStakes;
    address payable public manager; // LiquidationPoolManager
    address public tokenManager;

    struct Position {  address holder; uint256 TST; uint256 EUROs; }
    struct Reward { bytes32 symbol; uint256 amount; uint8 dec; }
    struct PendingStake { address holder; uint256 createdAt; uint256 TST; uint256 EUROs; }

    constructor(address _TST, address _EUROs, address _eurUsd, address _tokenManager) {
        TST = _TST;
        EUROs = _EUROs;
        eurUsd = _eurUsd;
        tokenManager = _tokenManager;
        manager = payable(msg.sender);
    }

    modifier onlyManager {
        require(msg.sender == manager, "err-invalid-user");
        _;
    }

    function stake(Position memory _position) private pure returns (uint256) {
        // @audit This comparison don't make sense
        // TST and EURO are different units
        // Convert them to a common unit before comparing
        return _position.TST > _position.EUROs ? _position.EUROs : _position.TST;
    }

    // @audit not clear to me. Ans: To incentivize a balance stake ratio
    // Why only account for only TST or EURO of holders stake?
    // Even worse, why sum them as though they are thesame unit? Vuln
    // Recomm: Sum their dollar(or any common unit) value
    function getStakeTotal() private view returns (uint256 _stakes) {
        // @audit iterate over unbounded loop; holders
        for (uint256 i = 0; i < holders.length; i++) {
            Position memory _position = positions[holders[i]];
            _stakes += stake(_position);
        }

    // @audit iterate over unbounded loop; holders & pendingStakes
    function getTstTotal() private view returns (uint256 _tst) {
        for (uint256 i = 0; i < holders.length; i++) {
            _tst += positions[holders[i]].TST;
        }
        for (uint256 i = 0; i < pendingStakes.length; i++) {
            _tst += pendingStakes[i].TST;
        }
    }

    function findRewards(address _holder) private view returns (Reward[] memory) {
        ITokenManager.Token[] memory _tokens = ITokenManager(tokenManager).getAcceptedTokens();
        Reward[] memory _rewards = new Reward[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            _rewards[i] = Reward(_tokens[i].symbol, rewards[abi.encodePacked(_holder, _tokens[i].symbol)], _tokens[i].dec);
        }
        return _rewards;
    }

    function holderPendingStakes(address _holder) private view returns (uint256 _pendingTST, uint256 _pendingEUROs) {
        for (uint256 i = 0; i < pendingStakes.length; i++) {
            PendingStake memory _pendingStake = pendingStakes[i];
            if (_pendingStake.holder == _holder) {
                _pendingTST += _pendingStake.TST;
                _pendingEUROs += _pendingStake.EUROs;
            }
        }
    }
    
    function position(address _holder) external view returns(Position memory _position, Reward[] memory _rewards) {
        _position = positions[_holder];
        (uint256 _pendingTST, uint256 _pendingEUROs) = holderPendingStakes(_holder);
        _position.EUROs += _pendingEUROs;
        _position.TST += _pendingTST;
        if (_position.TST > 0) _position.EUROs += IERC20(EUROs).balanceOf(manager) * _position.TST / getTstTotal();
        _rewards = findRewards(_holder);
    }

    function empty(Position memory _position) private pure returns (bool) {
        return _position.TST == 0 && _position.EUROs == 0;
    }

    function deleteHolder(address _holder) private {
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i] == _holder) {
                holders[i] = holders[holders.length - 1];
                holders.pop();
            }
        }
    }

    function deletePendingStake(uint256 _i) private {
        // @audit this is gas costly, especially if pendingStakes array is long
        // rather than shifting all the array items,
        // move the last item to the current index and pop the array
        for (uint256 i = _i; i < pendingStakes.length - 1; i++) {
            pendingStakes[i] = pendingStakes[i+1];
        }
        pendingStakes.pop();
    }

    function addUniqueHolder(address _holder) private {
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i] == _holder) return;
        }
        holders.push(_holder);
    }

    // @audit stake pending stake position i.e. any stake older than 1 day
    function consolidatePendingStakes() private {
        uint256 deadline = block.timestamp - 1 days;
        // @audit iterating over unbounded array length
        // Potential DoS
        // cache the array length
        // @Test correctness of this casting. Should be fine.
        for (int256 i = 0; uint256(i) < pendingStakes.length; i++) {
            PendingStake memory _stake = pendingStakes[uint256(i)];
            if (_stake.createdAt < deadline) {
                positions[_stake.holder].holder = _stake.holder;
                positions[_stake.holder].TST += _stake.TST;
                positions[_stake.holder].EUROs += _stake.EUROs;
                deletePendingStake(uint256(i));
                // pause iterating on loop because there has been a deletion. "next" item has same index
                // @audit Not that you cannot convert negative int to uint
                i--;
            }
        }
    }

    // @audit Potential DoS
    // steps to sabotage the efficacy of the protocol
    // Step 1: Bloat the pendingStakes or holders array
    // Prevent new stake positions from entering the pool i.e. DoS attack this function
    // Allow reward to accumulate
    // Step 2: Call this function so frequently the accumulated reward wouldn't be divisible to stakers
    function increasePosition(uint256 _tstVal, uint256 _eurosVal) external {
        require(_tstVal > 0 || _eurosVal > 0);
        consolidatePendingStakes(); // note: first stake pending positions
        // distribute accumulated fees to current stakers before adding new stakers
        ILiquidationPoolManager(manager).distributeFees();
        if (_tstVal > 0) IERC20(TST).safeTransferFrom(msg.sender, address(this), _tstVal);
        if (_eurosVal > 0) IERC20(EUROs).safeTransferFrom(msg.sender, address(this), _eurosVal);
        pendingStakes.push(PendingStake(msg.sender, block.timestamp, _tstVal, _eurosVal));
        addUniqueHolder(msg.sender);
    }

    function deletePosition(Position memory _position) private {
        deleteHolder(_position.holder);
        delete positions[_position.holder];
    }

    // @audit Potential DoS
    function decreasePosition(uint256 _tstVal, uint256 _eurosVal) external {
        consolidatePendingStakes();
        ILiquidationPoolManager(manager).distributeFees();
        require(_tstVal <= positions[msg.sender].TST && _eurosVal <= positions[msg.sender].EUROs, "invalid-decr-amount");
        if (_tstVal > 0) {
            // @audit make state changes before external calls
            IERC20(TST).safeTransfer(msg.sender, _tstVal);
            positions[msg.sender].TST -= _tstVal;
        }
        if (_eurosVal > 0) {
            // @audit make state changes before external calls
            IERC20(EUROs).safeTransfer(msg.sender, _eurosVal);
            positions[msg.sender].EUROs -= _eurosVal;
        }
        if (empty(positions[msg.sender])) deletePosition(positions[msg.sender]);
    }


    // @audit  won't work well with blacklistable tokens
    function claimRewards() external {
        ITokenManager.Token[] memory _tokens = ITokenManager(tokenManager).getAcceptedTokens();
        for (uint256 i = 0; i < _tokens.length; i++) {
            ITokenManager.Token memory _token = _tokens[i];
            uint256 _rewardAmount = rewards[abi.encodePacked(msg.sender, _token.symbol)];
            if (_rewardAmount > 0) {
                delete rewards[abi.encodePacked(msg.sender, _token.symbol)];
                if (_token.addr == address(0)) {
                    (bool _sent,) = payable(msg.sender).call{value: _rewardAmount}("");
                    require(_sent);
                } else {
                    IERC20(_token.addr).transfer(msg.sender, _rewardAmount);
                }   
            }

        }
    }

    // @audit Miss out on fees due precision loss; rounding error in
    // Not practical due to TST and EUROs having 18 decimals
    function distributeFees(uint256 _amount) external onlyManager {
        uint256 tstTotal = getTstTotal(); // @audit getTstTotal() is DoS prone
        if (tstTotal > 0) {
            IERC20(EUROs).safeTransferFrom(msg.sender, address(this), _amount);
            // @audit iterate over unbounded loop; holders
            for (uint256 i = 0; i < holders.length; i++) {
                address _holder = holders[i];
                // @audit precision loss; rounding error
                // they all receive zero if numerator < denominator
                positions[_holder].EUROs += _amount * positions[_holder].TST / tstTotal;
            }
            for (uint256 i = 0; i < pendingStakes.length; i++) {
                // @audit precision loss; rounding error
                // they all receive zero if numerator < denominator
                pendingStakes[i].EUROs += _amount * pendingStakes[i].TST / tstTotal;
            }
        }
    }

    function returnUnpurchasedNative(ILiquidationPoolManager.Asset[] memory _assets, uint256 _nativePurchased) private {
        for (uint256 i = 0; i < _assets.length; i++) {
            if (_assets[i].token.addr == address(0) && _assets[i].token.symbol != bytes32(0)) {
                (bool _sent,) = manager.call{value: _assets[i].amount - _nativePurchased}("");
                require(_sent);
            }
        }
    }

    // @audit bug leads
    /* Test One: Do users with higher stake position get more reward. Not always: @Bug alert
        Test Two: How do staking positions without EUROs pay for collateral assets. Ans. They are not reward
        - Do they receive collateral assets? Nope
        - If Yes, Who's EUROs position is used to pay for that collateral
        - How does this affect the original owner of that EUROs
        - When the original owner tries to withdraw (decreasePosition and claimReward), do they get back >= value that they put in?
        - Does the reward distribution function factor in price of TST when distributing rewards? Nope!
        - Is TST price factored in when calculating the totalStake or user's individual stake stake? @Bug alert!
        - Is TST price factored in any parts of the contract? Nope!
     */

    // @audit Look deeper into this function
    // @Test the value of Asset each holder receives is proportional to their stake position (factor both tokens)
    // @Test what happens when this function is called with no msg.value and zero token value. Nothing bad

    // Does a holder who staked only TST benefit from reward
    // If yes, how do they pay for the assets they receive?
    // Check to ensure pool is paying for certain types of holders (like this kind)
    // with the position of other holders.
    function distributeAssets(ILiquidationPoolManager.Asset[] memory _assets, uint256 _collateralRate, uint256 _hundredPC) external payable {
        consolidatePendingStakes(); // add pending stakes to positions mapping
        (,int256 priceEurUsd,,,) = Chainlink.AggregatorV3Interface(eurUsd).latestRoundData(); // get EurUsd latest price
        // @audit possibly inaccurate data due inaccurate comparison. see note above
        // @q How does this affect the outcome? What invariants or test reveals this
        uint256 stakeTotal = getStakeTotal();
        uint256 burnEuros; // Euros to be burnt. to balance EUROs supply
        uint256 nativePurchased;
        // @audit iterate over unbounded loop; holders. DoS
        for (uint256 j = 0; j < holders.length; j++) {
            Position memory _position = positions[holders[j]]; // staker's position
            // @audit returns the smaller of the TST or EUROs amounts for holder's position
            uint256 _positionStake = stake(_position);
            if (_positionStake > 0) {
                for (uint256 i = 0; i < _assets.length; i++) {
                    ILiquidationPoolManager.Asset memory asset = _assets[i];
                    if (asset.amount > 0) {
                        (,int256 assetPriceUsd,,,) = Chainlink.AggregatorV3Interface(asset.token.clAddr).latestRoundData();
                        // @audit Unfair distribution due to above reason
                        // User can swap tokenA of higher value but lower denomination
                        // to tokenB of lower value and higher to accumulate more reward without actually staking the most value
                        // @audit precision loss; rounding error
                        // if asset.amount == 0, _portion is set to 0
                        // _portion = (1e8 * 1e18)/1000000000e18 // 0
                        uint256 _portion = asset.amount * _positionStake / stakeTotal; // staker's share of the distributed asset
                        // @audit division before multiplication
                        // Euro value of staker's share of the distributed asset
                        // @Test accuracy of costInEuro. Ans: checks out
                        uint256 costInEuros = _portion * 10 ** (18 - asset.token.dec) * uint256(assetPriceUsd) / uint256(priceEurUsd)
                            * _hundredPC / _collateralRate;
                        // cap staker's portion to their _position.EUROs value
                        // ensures holders are not charged more than they can afford for their portion
                        // @audit fails to check if holders are paying less than they should for their portion
                        // How can I achieve paying less for my portion? Explore portion logic: _portion
                        // Accounting Risk: The more holders pay less for their portion, the higher the loss
                        // caused; the assets are essentially been bought for less than their worth
                        if (costInEuros > _position.EUROs) {
                            // set _portion to the token equivalent of holders staked EUROs position
                            // I.e. Making sure holder can afford their portion
                            // by preventing them for paying for more than they are receiving
                            _portion = _portion * _position.EUROs / costInEuros;
                            costInEuros = _position.EUROs; //
                        }
                        // Underflow reverts if user doesn't have enough _position.EUROs
                        // Can I cause this function to always revert (DoS) with the sizing of my position?
                        _position.EUROs -= costInEuros; // subtract the charge from stakers position
                        // store holders share of asset bought in rewards mapping
                        rewards[abi.encodePacked(_position.holder, asset.token.symbol)] += _portion;
                        // Burn Euros used to buy asset to balance the supply
                        burnEuros += costInEuros;
                        if (asset.token.addr == address(0)) {
                            // accounting (sum) of all the native tokens (asset) bought buy the pool
                            nativePurchased += _portion;
                        } else {
                            // pull the ERC20 tokens from the manager contract to this contract
                            // So its available for holders when they want to claim their rewards
                            // This is gas intensive. Why not sum all the _portion, and pull them all at once
                            // Rather than transferring each token for each holder individually,
                            // Sum all the tokens bought by all holders, i.e. have a local variable,
                            // for each token and update them in the loop
                            // you can use a mapping for that. Update the amount for each token type.
                            // After all, these tokens will still end up in this pool
                            IERC20(asset.token.addr).safeTransferFrom(manager, address(this), _portion);
                        }
                    }
                }
            }
            // update holders position state variable with the memory copy
            positions[holders[j]] = _position;
        }
        if (burnEuros > 0) IEUROs(EUROs).burn(address(this), burnEuros);
        returnUnpurchasedNative(_assets, nativePurchased);
    }
}
