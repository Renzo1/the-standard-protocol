
# FINDINGs
> H: 24 | M: 6 | L: 7

## [H-#] Incorrect Accounting in `LiquidationPool::distributeAssets()` Causes Permanent Loss of Holders' EUROs Position

Links:  
https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L220C92-L220C92

**Description:**

The formula for calculating `costInEuros` in the `distributeAsset()` function is incorrect. It erroneously multiplies `_portion` by `10e(18 - asset.token.dec)` instead of the correct `1e(18 - asset.token.dec)`, resulting in a cost that is an order of magnitude higher, causing the following if block to run and make erroneous changes to stakers position.

&nbsp;  
**Impact:**  
This error wipes out the EUROs position of holders without compensating them with the corresponding reward.

&nbsp;  
**Proof of Concept:**

Vulnerability Breakdown in Pseudocode

**Given the following scenario:**
- Liquidated Asset: wBtc = 0.005e8 (one token for simplicity) 
- btcusd price = 40000e8 
- wbtc decimals = 8 
- eurusd price = 1.12e8
- _hundredPC = 1e5
- _collateralRate = 110000

Position0.EUROs value = 100e18 \* 1e0 \* 1.12e8 \* 1e-8 = 112e8  
Position1.EUROs value = 0 \* 1e0 \* 1.12e8 \* 1e-8 = 0  
Position2.EUROs value = 100e18 \* 1e0 \* 1.12e8 \* 1e-8 = 112e8  
Position3.EUROs value = 5e18 \* 1e0 \* 1.12e8 \* 1e-8 = 5.6e8  
Position4.EUROs value = 100e18 \* 1e0 \* 1.12e8 \* 1e-8 = 112e8

Total Euros Locked = 341.6e8

*Note:*  
*\- Focus is on EUROs as its the only token in the pool that contributes to the objective function of the pool*

* * *

**distributeAssets() logic breakdown**

* * *

**stakeTotal** = getStakeTotal() == 341.6e8

*Note:*  
*The bugs in getStakeTotal() caused by incorrect comparison of TST and EUROs, and inaccurately calculation of total stake is assume to have been fixed, in effort to show differences in root causes. However, the Proof of Code, shows this bug persist with the original contract state.*

**burnEuros** == 0; // tracks EUROs used up by the pool, to be burnt for supply balance  
**nativePurchased** == 0; // tracks native token bought by the pool -- not relevant here

For Loop: loop through all holders and distribute rewards to them  
{  
Loop 1 //for position 0  
**\_position** = Position0  
**\_positionStake** = stake(\_position) == 112e8

(if 112e8 > 0) {  
Loop 1 (for wbtc)  
asset = wbtc

(if 0.005e8 > 0) {  
**\_portion** = 0.005e8 \* 112e8 / 341.6e8 == 0.00163934e8  
**costInEuros** = 0.00163934e8 \* 10e10 \* 40000e8 / 1.12e8 \* 1e5 / 110000 == 532.25325e18 // Should be 53.25e18

(if 532.25455e18 > 100e18) { // This condition should have been false  
\_portion = 0.00163934e8 \* 100e18 / 532.25455e18 == 0.00030799.924585e8 // 0  
**costInEuros** = \_position.EUROs == 100e8 ;  
}

Position0.EUROs -= 100e8 // wipes out stakers position  
**burnEuros** += 100e8  
(if reward native is token) {  
// We are not dealing with a native token

}  
(if reward native is erc20) {  
// transfers 0 tokens to the pool.  
}  
}  
}  
// Update Position0  
}  
// After looping through all holders it:  
// burns the burnEuros  
// Return native tokens that weren't bought

Key:  
{logic} : Logic block  
**bold font** : code variables  
(conditional statements)


**Proof of Code:**

<details><summary>Code</summary>

The provided test suite demonstrates the vulnerability's validity and severity.

### How to Run the Test:
- Due to the file size required to run this PoC, the suite is hosted on Github.
- To run the PoC, clone the repository.
- Minor changes, such as modifying function visibility, were made to enable successful test runs.
- All changes and additional files made to the original code are documented in the README and the respective files where the changes are made.

**Requirements:**
- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html).
- Clone the project codebase into your local workspace.
  ```bash
  git clone https://github.com/Renzo1/the-standard-protocol-2.git
  ```
- Run the following commands to install dependencies:
  ```bash
  npm install
  forge install
  ```
- Run the following command to execute the PoC:
  ```bash
  forge test --match-test "testAccountErrorLoss10e" -vvv
  ```

```javascript
function testAccountErrorLoss10e() public {

    ISmartVault[] memory vaults = new ISmartVault[](1);
    vaults = createVaultOwners(1);

    //////// Owner 1 variables ////////
    ISmartVault vault1 = vaults[0];
    address owner1 = vault1.owner();
    uint256 tstBalance1 = TST.balanceOf(owner1);
    uint256 euroBalance1 = EUROs.balanceOf(owner1);

    // Assert owner has EUROs and TST
    // i.e., mint vault.mint() in TSBuilder::createVaultOwners is activated
    assertGt(tstBalance1, 45 * 1e18);
    assertGt(euroBalance1, 45_000 * 1e18);

    //////// Create two random accounts Transfer tokens to them ////////
    address account1 = vm.addr(111222);
    address account2 = vm.addr(888999);

    vm.startPrank(owner1);
    TST.transfer(account1, 20 * 1e18);
    TST.transfer(account2, 20 * 1e18);
    EUROs.transfer(account1, 20_000 * 1e18);
    EUROs.transfer(account2, 20_000 * 1e18);
    vm.stopPrank();

    uint256 account1TstBalance = TST.balanceOf(account1);
    uint256 account2TstBalance = TST.balanceOf(account2);
    uint256 account1EurosBalance = EUROs.balanceOf(account1);
    uint256 account2EurosBalance = EUROs.balanceOf(account2);

    assertEq(account1TstBalance, 20 * 1e18, "TEST 1");
    assertEq(account2TstBalance, 20 * 1e18, "TEST 2");
    assertEq(account1EurosBalance, 20_000 * 1e18, "TEST 3");
    assertEq(account2EurosBalance, 20_000 * 1e18, "TEST 4");

    //////// Stake Tokens ////////
    vm.warp(block.timestamp + 2 days);

    vm.startPrank(account1);
    TST.approve(pool, account1TstBalance);
    EUROs.approve(pool, account1EurosBalance);
    liquidationPool.increasePosition(account1TstBalance, account1EurosBalance);
    vm.stopPrank();

    vm.startPrank(account2);
    TST.approve(pool, account2TstBalance);
    EUROs.approve(pool, account2EurosBalance);
    liquidationPool.increasePosition(account2TstBalance, account2EurosBalance);
    vm.stopPrank();

    vm.warp(block.timestamp + 2 days);

    // Assert LiquidationPool received the deposits
    assertEq(EUROs.balanceOf(pool), account1EurosBalance * 2, "TEST 5");
    assertEq(TST.balanceOf(pool), account1TstBalance * 2, "TEST 6");

    // starting prices: EUR/USD $11037; ETH/USD $2200; BTC/USD $42000; PAXGUSD $2000
    setPriceAndTime(11037, 1100, 20000, 1000); // Drop collateral value

    //////// Liquidate vault ////////

    // struct Reward { bytes32 symbol; uint256 amount; uint8 dec; }
    // Position { address holder; uint256 TST; uint256 EUROs; }

    // Account1 pre-liquidation Position
    ILiquidationPool.Position memory account1Position0;
    ILiquidationPool.Reward[] memory account1Reward0 = new ILiquidationPool.Reward[](3);
    (account1Position0, account1Reward0) = liquidationPool.position(account1);

    uint256 EurosPosition = account1Position0.EUROs;
    assertEq(account1EurosBalance, EurosPosition, "TEST 7");

    // Bug fix: Without granting pool BURNER_ROLE, distributeAssets() reverts
    vm.startPrank(SmartVaultManager);
    IEUROs(euros_).grantRole(IEUROs(euros_).BURNER_ROLE(), pool);
    vm.stopPrank();

    vm.startPrank(liquidator);
    liquidationPoolManagerContract.runLiquidation(1);
    vm.stopPrank();

    // account rewards
    ILiquidationPool.Position memory account1Position1;
    ILiquidationPool.Reward[] memory account1Reward1 = new ILiquidationPool.Reward[](3);
    (account1Position1, account1Reward1) = liquidationPool.position(owner1);

    // Assert account1 EUROs Position is wiped
    uint256 EurosPosition1 = account1Position1.EUROs;
    assertEq(EurosPosition1, 0, "TEST 8");

    // Assert account1 receive no Reward
    assertEq(account1Reward0[0].amount, account1Reward1[0].amount, "TEST 9");
    assertEq(account1Reward0[1].amount, account1Reward1[1].amount, "TEST 10");
    assertEq(account1Reward0[2].amount, account1Reward1[2].amount, "TEST 11");
}
```

</details>

&nbsp;  
**Tools Used:**

- Manual review
- Foundry

&nbsp;  
**Recommended Mitigation Steps:**  
Change `10e10` to `1e10` in the `costInEuros` calculation.

```diff
if (asset.amount > 0) {
                        (,int256 assetPriceUsd,,,) = Chainlink.AggregatorV3Interface(asset.token.clAddr).latestRoundData();
                        uint256 _portion = asset.amount * _positionStake / stakeTotal;
-                        uint256 costInEuros = _portion * 10 ** (18 - asset.token.dec) * uint256(assetPriceUsd) / uint256(priceEurUsd) * _hundredPC / _collateralRate;
+                        uint256 costInEuros = _portion * 1 ** (18 - asset.token.dec) * uint256(assetPriceUsd) / uint256(priceEurUsd) * _hundredPC / _collateralRate;
                        if (costInEuros > _position.EUROs) {
                            _portion = _portion * _position.EUROs / costInEuros;
                            costInEuros = _position.EUROs;
                        }
                        _position.EUROs -= costInEuros;
                        rewards[abi.encodePacked(_position.holder, asset.token.symbol)] += _portion;
                        burnEuros += costInEuros;
                        if (asset.token.addr == address(0)) {
                            nativePurchased += _portion;
                        } else {
                            // IERC20(asset.token.addr).safeTransferFrom(manager, address(this), _portion);

                            // Only comment the above line and uncomment this one when running testAssetsDistribution
                            IERC20(asset.token.addr).safeTransferFrom(msg.sender, address(this), _portion);
                        }
                    }
```</details></details>
```

</details>


## [H-#] Having no Cap for Liquidated Assets to Sell in `LiquidationPool` causes permanent of holders EUROs position

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L211-L238

&nbsp;
**Description:**
When the total value of the liquidated asset to be sold to the pool exceeds the total value of 'EUROs' available for the trade, the `costInEuros` is erroneously calculated. This results in the execution of the following if block, which wipes out stakers' balances. The miscalculation causes the if block to run, leading to inaccurate changes in stakers' positions.


&nbsp;
**Impact:**
This error wipes out the EUROs position of holders without compensating them with the corresponding reward.

&nbsp;
**Proof of Concept:**


<details><summary>Vulnerability Breakdown in Pseudocode</summary>


** Given the following scenario: **
Liquidated Asset: wBtc = 1e8 (limiting to one token for simplicity)
btcusd price = 40000e8
wbtc decimals = 8
eurusd price = 1.12e8
_hundredPC = 1e5
_collateralRate = 110000

Position0.TST value = 1000 * 1e0 *1e8 = 1000e8 (amount x price)
Position0.EUROs value = 100 * 1e0 * 1.12e8 = 112e8
Total Staked value = 1112e8 

Position1.TST value = 1000 * 1e0 * 1e8 = 1000e18
Position1.EUROs value = 0 * 1e0 * 1.12e8 = 0
Total Staked value = 1000e8 

Position2.TST value = 0 * 1e0 * 1e8 = 0
Position2.EUROs value = 100 * 1e0 * 1.12e8 = 112e8
Total Staked value = 112e8

Position3.TST value = 100 * 1e0 * 1e8 = 100e8
Position3.EUROs value = 5 * 1e0 * 1.12e8 = 5.6e8
Total Staked value = 105.6e8

Position4.TST value = 10  * 1e0 * 1e8 = 10e8 
Position4.EUROs value = 100  * 1e0 * 1.12e8 = 112e8
Total Staked value = 122e8

Total Value Locked (TVL) = 2441.6e8

Note: 
- Position0 adds the most value
- Position4 adds more value to the pool than Position2, Position1 and Positon3
- Position2 adds more value to the pool than Position1 and Positon3
- Positon1 adds more value than Position3
- Position3 adds the least value

***
distributeAssets() logic breakdown
***
stakeTotal = getStakeTotal()  == 115
|-- getStakeTotal() = 115
    |-- stake() = For Loop:
- position0 returns 100 
- position1 returns 0
- position2 returns 0
- position3 returns 5
- position4 returns 10

Note: 
- stake() compares `_position.TST` and `_position.EUROs` amount, not value, which is not a recommended way to compare different tokens.
- Position3 return value is greater than Position1 and Position2, despite adding the least value to the protocol.

burnEuros == 0; (tracks EUROs used up by the pool, to be burnt for supply balance)
nativePurchased == 0; (tracks native token bought by the pool, used to calculate tokens returned to the liquidationPoolManager)

For Loop: loop through all holders and distribute rewards to them
{
Loop 1 // for position0
_position = Position0
_positionStake = stake(_position) == 100 
 (if 100 > 0) {
Loop through each accepted collateral asset (which in our simple example is just wBtc)
asset = wbtc
 (if 1e8 > 0) { 
_portion = 1e8 * 100 / 115 == 86956521
costInEuros = 86956521 * 1e10 * 40000e8 / 1.12e8 * 1e5 / 110000 == 2.8232637e22
(if 28232.637e18 > 100 ) {
_portion = 86956521 * 100 / 2.8232637e+23 == 3.08e-14 == 0
costInEuros = 100
}

Position0.EUROs -= 100 // wipes out stakers position  
burnEuros += 100
(if reward native is token) { 
// We are not dealing with a native token

                }
(if reward native is erc20) { 
// transfers 0 tokens to the pool.
                }
            }
    }
// Update Position0
}
// After looping through all holders it:
// burns the burnEuros
// Return native tokens that weren't bought

Note:
I changed 10e10 to 1e10 in costInEuros calculation to fix a bug that causes the value to incorrectly increase by an order of magnitude.
Position0 EUROs position is drained but receives zero reward
Position0 EUROs are lost permanently as it is added to burnEuros 
Position0 updated position:
- Position0.TST value = 1000 * 1e8 (amount x price)
- Position0.EUROs value = 0 * 20e8
- Total Staked value = 1000e8
Net Loss is 2000

Key:
{logic}: Logic block
bold font : code variables
(conditional statements)


&nbsp;
**Proof of Code:**

<details><summary>Code</summary>

The provided test suite demonstrates the vulnerability's validity and severity.

### How to Run the Test:
- Due to the file size required to run this PoC, the suite is hosted on Github.
- To run the PoC, clone the repository.
- Minor changes, such as modifying function visibility, were made to enable successful test runs.
- All changes and additional files made to the original code are documented in the README and the respective files where the changes are made.

**Requirements:**
- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html).
- Clone the project codebase into your local workspace.
  ```bash
  git clone https://github.com/Renzo1/the-standard-protocol-2.git
  ```
- Run the following commands to install dependencies:
  ```bash
  npm install
  forge install
  ```
- Run the following command to execute the PoC:
  ```bash
  forge test --match-test "testLiquidatedAssetNoCap" -vvv
  ```

```javascript
function testAccountErrorLoss10e() public {

    ISmartVault[] memory vaults = new ISmartVault[](1);
    vaults = createVaultOwners(1);

    //////// Owner 1 variables ////////
    ISmartVault vault1 = vaults[0];
    address owner1 = vault1.owner();
    uint256 tstBalance1 = TST.balanceOf(owner1);
    uint256 euroBalance1 = EUROs.balanceOf(owner1);

    // Assert owner has EUROs and TST
    // i.e., mint vault.mint() in TSBuilder::createVaultOwners is activated
    assertGt(tstBalance1, 45 * 1e18);
    assertGt(euroBalance1, 45_000 * 1e18);

    //////// Create two random accounts Transfer tokens to them ////////
    address account1 = vm.addr(111222);
    address account2 = vm.addr(888999);

    vm.startPrank(owner1);
    TST.transfer(account1, 20 * 1e18);
    TST.transfer(account2, 20 * 1e18);
    EUROs.transfer(account1, 20_000 * 1e18);
    EUROs.transfer(account2, 20_000 * 1e18);
    vm.stopPrank();

    uint256 account1TstBalance = TST.balanceOf(account1);
    uint256 account2TstBalance = TST.balanceOf(account2);
    uint256 account1EurosBalance = EUROs.balanceOf(account1);
    uint256 account2EurosBalance = EUROs.balanceOf(account2);

    assertEq(account1TstBalance, 20 * 1e18, "TEST 1");
    assertEq(account2TstBalance, 20 * 1e18, "TEST 2");
    assertEq(account1EurosBalance, 20_000 * 1e18, "TEST 3");
    assertEq(account2EurosBalance, 20_000 * 1e18, "TEST 4");

    //////// Stake Tokens ////////
    vm.warp(block.timestamp + 2 days);

    vm.startPrank(account1);
    TST.approve(pool, account1TstBalance);
    EUROs.approve(pool, account1EurosBalance);
    liquidationPool.increasePosition(account1TstBalance, account1EurosBalance);
    vm.stopPrank();

    vm.startPrank(account2);
    TST.approve(pool, account2TstBalance);
    EUROs.approve(pool, account2EurosBalance);
    liquidationPool.increasePosition(account2TstBalance, account2EurosBalance);
    vm.stopPrank();

    vm.warp(block.timestamp + 2 days);

    // Assert LiquidationPool received the deposits
    assertEq(EUROs.balanceOf(pool), account1EurosBalance * 2, "TEST 5");
    assertEq(TST.balanceOf(pool), account1TstBalance * 2, "TEST 6");

    // starting prices: EUR/USD $11037; ETH/USD $2200; BTC/USD $42000; PAXGUSD $2000
    setPriceAndTime(11037, 1100, 20000, 1000); // Drop collateral value

    //////// Liquidate vault ////////

    // struct Reward { bytes32 symbol; uint256 amount; uint8 dec; }
    // Position { address holder; uint256 TST; uint256 EUROs; }

    // Account1 pre-liquidation Position
    ILiquidationPool.Position memory account1Position0;
    ILiquidationPool.Reward[] memory account1Reward0 = new ILiquidationPool.Reward[](3);
    (account1Position0, account1Reward0) = liquidationPool.position(account1);

    uint256 EurosPosition = account1Position0.EUROs;
    assertEq(account1EurosBalance, EurosPosition, "TEST 7");

    // Bug fix: Without granting pool BURNER_ROLE, distributeAssets() reverts
    vm.startPrank(SmartVaultManager);
    IEUROs(euros_).grantRole(IEUROs(euros_).BURNER_ROLE(), pool);
    vm.stopPrank();

    vm.startPrank(liquidator);
    liquidationPoolManagerContract.runLiquidation(1);
    vm.stopPrank();

    // account rewards
    ILiquidationPool.Position memory account1Position1;
    ILiquidationPool.Reward[] memory account1Reward1 = new ILiquidationPool.Reward[](3);
    (account1Position1, account1Reward1) = liquidationPool.position(owner1);

    // Assert account1 EUROs Position is wiped
    uint256 EurosPosition1 = account1Position1.EUROs;
    assertEq(EurosPosition1, 0, "TEST 8");

    // Assert account1 receive no Reward
    assertEq(account1Reward0[0].amount, account1Reward1[0].amount, "TEST 9");
    assertEq(account1Reward0[1].amount, account1Reward1[1].amount, "TEST 10");
    assertEq(account1Reward0[2].amount, account1Reward1[2].amount, "TEST 11");
}
```

</details>

&nbsp;
**Tools Used:**

- Manual review
- Foundry

&nbsp;
**Recommended Mitigation Steps:**
- `Stake()` should return the USD value of stakers' positions.
- Add a condition to check if the Euro value of the total asset to be sold is greater than the Euros available to purchase them (Euro position of stakers eligible for reward). If true, cap the value of the amount of assets to sell to the total Euro available for trade.


```diff
    function stake(Position memory _position) private pure returns (uint256) {
-        return _position.TST > _position.EUROs ? _position.EUROs : _position.TST;
+        return _position.EUROs;
    }
```

```diff
+       if (totalAssetValue() > stakeTotal value) totalAssetValue = capTotalAssetToStakeTotal() // This is pseudocode
        for (uint256 i = 0; i < _assets.length; i++) {
                            ILiquidationPoolManager.Asset memory asset = _assets[i];
                            if (asset.amount > 0) {
                                (,int256 assetPriceUsd,,,) = Chainlink.AggregatorV3Interface(asset.token.clAddr).latestRoundData();
                                uint256 _portion = asset.amount * _positionStake / stakeTotal;
                                uint256 costInEuros = _portion * 10 ** (18 - asset.token.dec) * uint256(assetPriceUsd) / uint256(priceEurUsd)
                                    * _hundredPC / _collateralRate;
                                if (costInEuros > _position.EUROs) {
                                    _portion = _portion * _position.EUROs / costInEuros;
                                    costInEuros = _position.EUROs;
                                }
                                _position.EUROs -= costInEuros;
                                rewards[abi.encodePacked(_position.holder, asset.token.symbol)] += _portion;
                                burnEuros += costInEuros;
                                if (asset.token.addr == address(0)) {
                                    nativePurchased += _portion;
                                } else {
                                    // IERC20(asset.token.addr).safeTransferFrom(manager, address(this), _portion);

                                    // Only comment the above line and uncomment this one when running testAssetsDistribution
                                    IERC20(asset.token.addr).safeTransferFrom(msg.sender, address(this), _portion);
                                }
                            }
                        }
```


## [H-1] `Stake()` Not Accounting for Some EUROs in the Pool Decreases the Efficiency of the Pool

**GitHub Link:** [LiquidationPool.sol - Lines 44-46](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L44-L46)

&nbsp;
**Description:**
When liquidated assets are to be sold in the pool, the `getStakeTotal()` function is called to measure the value of stake in the pool, which is then used to ration the reward distribution. However, the `getStakeTotal()` function loops through all staking positions and sums the smaller of TST or EUROs amount. This means that any position with only EUROs wouldn't be factored into the liquidation process. These EUROs remain untouched even if the liquidation process requires more liquidity to complete the trade. This inefficiency contradicts the objective function of the pool.

&nbsp;
**Impact:**
The Total Value Locked (TVL) in this pool gives a misleading impression of liquidity depth. In truth, if a significant position in the pool is single-sided with EUROs, and there's a large liquidation that requires a substantial portion of the total EUROs in the pool, the liquidation wouldn't be completely processed. The EUROs will be at risk of under-collateralization due to the implied delay in selling off the collateral asset and covering the loss while the asset prices fall.

**Tools Used:**
- Manual Review

&nbsp;
**Recommended Mitigation Steps:**
Only factor EUROs positions in the `stake()` calculation.

```diff
    function stake(Position memory _position) private pure returns (uint256) {
-        return _position.TST > _position.EUROs ? _position.EUROs : _position.TST;
+        return _position.EUROs;
    }


## [H-1] High Capital Inefficiency in the Liquidity Pool could lead to undercollateralization

**GitHub Link:** [LiquidationPool.sol - Lines 44-46](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L44-L46)

&nbsp;
**Description:**
When liquidated assets are to be sold in the pool, the `getStakeTotal()` function is called to measure the value of stake in the pool, which is then used to ration the reward distribution. However, the `getStakeTotal()` function loops through all staking positions and sums the smaller of TST or EUROs amount. This means that any position with only EUROs wouldn't be factored into the liquidation process. These EUROs remain untouched even if the liquidation process requires more liquidity to complete the trade. This inefficiency contradicts the objective function of the pool.
Additionally, when fees are distributed to stakers, they are only distributed to stakers with TST positions. This discourages the staking of EUROs which is the asset required by the pool for processing liquidations.

&nbsp;
**Impact:**
The Total Value Locked (TVL) in this pool gives a misleading impression of liquidity depth. In truth, if a significant position in the pool is single-sided with EUROs, and there's a large liquidation that requires a substantial portion of the total EUROs in the pool, the liquidation wouldn't be completely processed. The EUROs will be at risk of under-collateralization due to the implied delay in selling off the collateral asset and covering the loss while the asset prices fall.

**Tools Used:**
- Manual Review

&nbsp;
**Recommended Mitigation Steps:**
Only factor EUROs positions in the `stake()` calculation.

```diff
    function stake(Position memory _position) private pure returns (uint256) {
-        return _position.TST > _position.EUROs ? _position.EUROs : _position.TST;
+        return _position.EUROs;
    }

Distribute fees to EUROs stakers.


## [H-#] `stake()` Comparison of EUR and TST by Amounts Leads to Disproportionate Reward Distribution

&nbsp;

**Description:**

According to the [whitepaper (pg 15 - CH 2.8.2)](https://assets-global.website-files.com/6422757f5e8ba638bea66086/656f0638221d009eb33e6e63_The_Standard_-_Release_Version_2.5.pdf), the distribution formula "ensures a fair distribution of assets based on each participant's contribution to the liquidation pool in terms of sEURO and TST tokens." However, the actual code falls short of this objective. The rewards in terms of liquidated assets and fees are disproportionate to the value stakers add to the pool. Stakers without TST positions receive no fees and rewards, despite contributing the resources necessary to achieve the pool's objective function.

&nbsp;

**Impact:**

This discrepancy disincentivizes staking activities in the network, potentially leading to a decline in TVL and a shortage of liquidity necessary for facilitating liquidation.

&nbsp;

**Proof of Concept:**

### Given the following scenario:

Liquidated Asset: wBTC = 1e8 (limiting to one token for simplicity)
BTC/USD price = 40000e8
wBTC decimals = 8
EUR/USD price = 1.12e8
_hundredPC = 1e5
_collateralRate = 110000

Position0.TST value = 1000 * 1e0 * 1e8 = 1000e8
Position0.EUROs value = 100 * 1e0 * 1.12e8 = 112e8
Total Staked value = 1112e8 

[... Other positions described similarly ...]

Total Value Locked (TVL) = 2441.6e8

### distributeAssets() Logic Breakdown:

stakeTotal = getStakeTotal() == 115
|- getStakeTotal() = 115
	|-  stake() = For Loop:
// Sum the smaller amount of the staked tokens
// This is a technique to incentivize a balanced stake of both tokens
- position0 returns 100 
- position1 returns 0
- position2 returns 0
- position3 returns 5
- position4 returns 10

**Note:**
- The stake() function compares the amounts of `_position.TST` and `_position.EUROs`, not their values. This approach is not recommended for comparing different tokens.
- The return value of Position3 is greater than that of Position1 and Position2, despite contributing the least value to the protocol.
- Despite adding value to the pool, Position1 and Position2 will not participate in the reward distribution.

&nbsp;

**Proof of Code:**

<details><summary>Code</summary>

```javascript
// we use javascript instead of solidity to be able to access JS keywords for formatting
// Area of focus
@> (int256 swap0, int256 swap1) = _univ3pool.swap()
// ...
```

</details>

&nbsp;

**Tools Used:**
- Manual review

&nbsp;

**Recommended Mitigation Steps:**

Reward stakers according to the effective value added to the pool. Effective value is the value that takes the pool closer to achieving its objective function, which is processing liquidation.
```



## [H-1] Potential Denial of Service (DoS) Attack in `runLiquidation()` Function Prevent Vault Liquidation

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L119-L133

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L211-L238

**Description:**
The `runLiquidation()` function contains sub-function calls that iterate through the `pendingStakes`, `holders`, and `_asset` arrays. As the protocol grows, these arrays become longer, resulting in increased gas consumption when calling the function. A malicious attacker could intentionally lengthen these arrays, making the `distributeAsset()` function unresponsive and preventing the liquidation of a vault.

**Impact:**
Inability to liquidate vaults as intended may lead to undercollateralization of the EUROs token.

**Proof of Concept:**
- John (Attacker) anticipates vault liquidation.
- He calls `increasePosition()` repeatedly to lengthen the pending stake array.
- When `LiquidationPoolManager::runLiquidation` is executed, it fails with an "out of gas" error.
- This prevents John's vault from being liquidated.

**Proof of Code:**
<details><summary>Code</summary>

```javascript
// We use JavaScript instead of Solidity to access JS keywords for formatting.
// Area of focus
@> (int256 swap0, int256 swap1) = _univ3pool.swap()
// ...
```

</details>

**Tools Used:**
- Manual review
- Foundry

**Recommended Mitigation Steps:**
To address this issue, a thorough examination of the contract architecture is required. Consider exploring gas-efficient alternatives, such as using mappings instead of arrays.

## [H-1] Missing BURNER_ROLE for EURO in `LiquidationPool` Causes `distributeAssets()` to revert

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L239C20-L239C20

**Description:**
When liquidated assets are sent to the LiquidationPool to be sold, the EUROs used in buying these assets are burned at the end of the `distributeAssets()` function call. However, the function call fails due to `LiquidationPool` being unable to burn EUROs because it is missing the `BURNER_ROLE` necessary to successfully complete this action.


**Impact:**
As a result, no liquidated assets are sold, leaving EUROs under-collateralized.

**Proof of Code:**

<details><summary>Code</summary>

The provided test suite demonstrates the vulnerability's validity and severity.

### How to Run the Test:
- Due to the file size required to run this PoC, the suite is hosted on Github.
- To run the PoC, clone the repository.
- Minor changes, such as modifying function visibility, were made to enable successful test runs.
- All changes and additional files made to the original code are documented in the README and the respective files where the changes are made.

**Requirements:**
- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html).
- Clone the project codebase into your local workspace.
  ```bash
  git clone https://github.com/Renzo1/the-standard-protocol-2.git
  ```
- Run the following commands to install dependencies:
  ```bash
  npm install
  forge install
  ```
- Run the following command to execute the PoC:
  ```bash
  forge test --match-test "testMissingBurnerRole" -vvv
  ```

```javascript

    function testMissingBurnerRole() public {
        // //////// Create one vault ////////
        ISmartVault[] memory vaults = new ISmartVault[](20);
        vaults = createVaultOwners(20);

        //////// Owner 1 variables ////////
        ISmartVault vault1 = vaults[0];
        address owner1 = vault1.owner();
        uint256 tstBalance1 = TST.balanceOf(owner1);
        uint256 euroBalance1 = EUROs.balanceOf(owner1);


        //////// Transfer EUROs to LiquidationPool ////////
        vm.startPrank(owner1);
        EUROs.transfer(pool, euroBalance1);
        vm.stopPrank();

        uint256 poolEurosBalance = EUROs.balanceOf(pool);
        assertEq(euroBalance1, poolEurosBalance); // Verify pool has EUROs in its account

        //////// Burn EUROs in Pool ////////
        vm.startPrank(pool);
        vm.expectRevert();
        EUROs.burn(pool, euroBalance1); // This line fails with a missing role error
        vm.stopPrank();
    }
```

</details>

**Tools Used:**
- Manual Review
- Foundry

**Recommended Mitigation Steps:**
Grant the `LiquidationPool` contract the `BURNER_ROLE` in the `initialize()` or a dedicated function in `SmartVaultManagerV5`

```diff
function initialize() initializer public {
+    IEUROs(euros).grantRole(IEUROs(euros).BURNER_ROLE(), address(LiquidationPool));
}
```
## [M-#] Excessive deployment of Vault contracts adds to the degradation of the blockchain network.


https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultManagerV5.sol#L86-L87


**Description:**

When a vault is liquidated, the `SmartVaultManagerV5` revokes the vaults right to burn and mint EURO, effectively rendering it useless. Their MINTER_ROLE() and BURNER_ROLE() roles for EUROs are revoked, and not granted back, even if the vaults are recredited. This is the equivalent of rejecting a user from a lending protocol like GMX after if they have been liquidated in the past, even if they return with a healthy position -- but worse. This is wasteful, gas inefficient, and net negative for the entire blockchain network, as it adds garbage data to the blockchain network. i.e. bloating the network. It is our duty as developers and security researcher to ensure the sanctity of the blockchain network and it's maintainance if we want to guarantee its sustainability.


**Impact:**

Every liquidated vault adds trash data to its host blockchain network, which hikes the block space demand and consequently cost.


**Tools Used:**
- Manual review

**Recommended Mitigation Steps:**

Consider alternative design choices for the vault contracts the don't resort to dumping useless data on the blockchain, and doesn't threaten the security of the network.

## [M-#] Pricision Error in `distributeAssets()` Could Lead to Undercollateralization of EUROs

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L220

**Description:**

Precision error in `distributeAsset` when distributing 8 decimal tokens like WBTC leads to users missing out on rewards and undercollateralization of EUROs. The larger the `stakedTotal`, the larger the denomination to divide by, causing `_portion` for some users to be 0. Consequently, some collateral will not be sold in the pool and sent back to LiquidationPoolManager despite having enough pool balance to buy these tokens. Assets that aren't sold are sent back to the LiquidationPoolManager, which then sends it to the `protocol` (i.e., treasury).

&nbsp;

**Impact:**

The delay between the time of liquidation and selling of these assets to cover the loss exposes EUROs to undercollateralization.

&nbsp;

**Proof of Concept:**

Calculating a staker's portion in the given conditions results in zero.
- wBTC reward: 1e8 (1 BTC)
- Staker's positions: 1e18
- Total Stake: 1000000000e18

Although the discrepancy between the staker's position and total stake is so wide, making the effect of such transactions seem almost inconsequential, this can accumulate over time or over multiple users to cause a significant impact on the protocol.

```javascript
// uint256 _portion = asset.amount * _positionStake / stakeTotal;
_portion = (1e8 * 1e18) / 1000000000e18 // 0
```

&nbsp;

**Proof of Code:**

<details><summary>Code</summary>

```javascript
// We use JavaScript instead of Solidity to be able to access JS keywords for formatting
// Area of focus
@> (int256 swap0, int256 swap1) = _univ3pool.swap()
// ...
```

</details>

&nbsp;

**Tools Used:**

- Manual Review
- Foundry

&nbsp;

**Recommended Mitigation Steps:**

Convert 8 decimal tokens to 18 before calculating stakers' portion.


## [H-#] Potential Denial of Service (DoS) Attack in `runLiquidation()` Function Prevent Vault Liquidation

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L119-L133

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L211-L238

**Description:**
The `runLiquidation()` function contains sub-function calls that iterate through the `pendingStakes`, `holders`, and `_asset` arrays. As the protocol grows, these arrays become longer, resulting in increased gas consumption when calling the function. A malicious attacker could intentionally lengthen these arrays, making the `distributeAsset()` function unresponsive and preventing the liquidation of a vault.

**Impact:**
The inability to liquidate vaults as intended may lead to the undercollateralization of the EUROs token.

**Proof of Concept:**
- John (Attacker) anticipates vault liquidation.
- He calls `increasePosition()` repeatedly to lengthen the pending stake array.
- When `LiquidationPoolManager::runLiquidation` is executed, it fails with an "out of gas" error.
- This prevents John's vault from being liquidated.

**Proof of Code:**

<details><summary>Code</summary>

The provided test suite demonstrates the vulnerability's validity and severity.

### How to Run the Test:
- Due to the file size required to run this PoC, the suite is hosted on Github.
- To run the PoC, clone the repository.
- Minor changes, such as modifying function visibility, were made to enable successful test runs.
- All changes and additional files made to the original code are documented in the README and the respective files where the changes are made.

**Requirements:**
- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html).
- Clone the project codebase into your local workspace.
  ```bash
  git clone https://github.com/Renzo1/the-standard-protocol-2.git
  ```
- Run the following commands to install dependencies:
  ```bash
  npm install
  forge install
  ```
- Run the following command to execute the PoC:
  ```bash
  forge test --match-test "testLiquidatorCantLiquidateVault" -vvv
  ```

```javascript

function testLiquidatorCantLiquidateVault() public {
        vm.txGasPrice(1);

        // //////// Create one vault ////////
        ISmartVault[] memory vaults = new ISmartVault[](20);
        vaults = createVaultOwners(20);

        //////// Owner 1 variables ////////
        ISmartVault vault1 = vaults[0];
        address owner1 = vault1.owner();
        uint256 tstBalance1 = TST.balanceOf(owner1);
        uint256 euroBalance1 = EUROs.balanceOf(owner1);


        //////// Stake Tokens ////////
        vm.warp(block.timestamp + 2 days);

        vm.startPrank(owner1);
        TST.approve(pool, tstBalance1);
        EUROs.approve(pool, euroBalance1);
        liquidationPool.increasePosition( tstBalance1, euroBalance1);
        vm.stopPrank();

        vm.warp(block.timestamp + 2 days);

        //////// Drop collateral assets value to liquidation threshold ////////

        // starting prices: EUR/USD $11037; ETH/USD $2200; BTC/USD $42000; PAXGUSD $2000
        setPriceAndTime( 11037, 1100, 20000, 1000); // Drop collateral value

        //////// Liquidate vault 1 ////////

        // Bug fix: Without granting pool BURNER_ROLE, distributeAssets() reverts
        vm.startPrank(SmartVaultManager);
        IEUROs(euros_).grantRole(IEUROs(euros_).BURNER_ROLE(), pool);
        vm.stopPrank();

        vm.startPrank(liquidator);
        uint256 gasStart1 = gasleft(); // see gas cost for subsequent transaction
        liquidationPoolManagerContract.runLiquidation(1);
        uint256 gasEnd1 = gasleft();
        vm.stopPrank();

        vm.warp(block.timestamp + 2 days);

        uint256 gasUsed1 = (gasStart1 - gasEnd1) * tx.gasprice;

        //////// Add more Holders to liquidationPool ////////

        for(uint256 i = 1; i < vaults.length; i++){

            vm.startPrank(vaults[i].owner());
            TST.approve(pool, tstBalance1);
            EUROs.approve(pool, euroBalance1);
            liquidationPool.increasePosition( 1, 1);
            vm.stopPrank();

        }

        //////// Liquidate vault 2 ////////
        vm.startPrank(liquidator);
        uint256 gasStart2 = gasleft(); // see gas cost for subsequent transaction
        liquidationPoolManagerContract.runLiquidation(2);
        uint256 gasEnd2 = gasleft();
        vm.stopPrank();

        uint256 gasUsed2 = (gasStart2 - gasEnd2) * tx.gasprice;

        //////// Assert increase in gas cost for both transactions ////////
        
        assertGt(gasUsed2, gasUsed1,"DoS TEST 1");
    }
```

</details>

**Tools Used:**
- Manual review
- Foundry

**Recommended Mitigation Steps:**
To address this issue, a thorough examination of the contract architecture is required. Consider exploring gas-efficient alternatives, such as using mappings instead of arrays.

## [H - 1] `addUniqueHolder()` Looping Through `holders` Array for Stakers' Positions Poses a Potential Denial of Service (DoS) Attack


https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L141


&nbsp;
**Description:**
There is a potential DoS attack risk in the `increasePosition()` function due to the `addUniqueHolder()` method iterating over unbounded array lengths of `holders`, When a user wants to increase their position.


&nbsp;
**Impact:**
If the `holders` array becomes excessively long, leading to an unresponsive state due to an Out of Gas error, users' funds will be permanently locked in the contract. This could mean death for the protocol as new liquidity can't enter the system.

&nbsp;
**Proof of Concept:**  
A malicious actor could disrupt the network by creating numerous addresses and spamming the network with transactions. This could result in the `holders` array becoming too long to iterate over efficiently. Effectively preventing withdrawals.


&nbsp;
**Proof of Code:**

<details><summary>Code</summary>

The provided test suite demonstrates the vulnerability's validity and severity.

### How to Run the Test:
- Due to the file size required to run this PoC, the suite is hosted on Github.
- To run the PoC, clone the repository.
- Minor changes, such as modifying function visibility, were made to enable successful test runs.
- All changes and additional files made to the original code are documented in the README and the respective files where the changes are made.

**Requirements:**
- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html).
- Clone the project codebase into your local workspace.
  ```bash
  git clone https://github.com/Renzo1/the-standard-protocol-2.git
  ```
- Run the following commands to install dependencies:
  ```bash
  npm install
  forge install
  ```
- Run the following command to execute the PoC:
  ```bash
  forge test --match-test "testPositionIncrementDoS" -vvv
  ```

```javascript

  function testPositionIncrementDoS() public {
        vm.txGasPrice(1);

        // //////// Create one vault ////////
        ISmartVault[] memory vaults = new ISmartVault[](20);
        vaults = createVaultOwners(20);

        //////// Owner 1 variables ////////
        ISmartVault vault1 = vaults[0];
        address owner1 = vault1.owner();
        uint256 tstBalance1 = TST.balanceOf(owner1);
        uint256 euroBalance1 = EUROs.balanceOf(owner1);


        //////// Stake Tokens ////////
        vm.warp(block.timestamp + 2 days);

        vm.startPrank(owner1);
        TST.approve(pool, tstBalance1);
        EUROs.approve(pool, euroBalance1);
        uint256 gasStart1 = gasleft(); // see gas cost for subsequent transaction
        liquidationPool.increasePosition( tstBalance1/2, euroBalance1/2);
        uint256 gasEnd1 = gasleft();
        vm.stopPrank();

        vm.warp(block.timestamp + 2 days);

        uint256 gasUsed1 = (gasStart1 - gasEnd1) * tx.gasprice;


        //////// Add more Holders to liquidationPool ////////

        for(uint256 i = 1; i < vaults.length; i++){

            vm.startPrank(vaults[i].owner());
            TST.approve(pool, tstBalance1);
            EUROs.approve(pool, euroBalance1);
            liquidationPool.increasePosition( 1, 1);
            vm.stopPrank();

        }

        vm.warp(block.timestamp + 2 days);

        //////// Decrease 2nd half Position ////////

        vm.startPrank(owner1);
        TST.approve(pool, tstBalance1);
        EUROs.approve(pool, euroBalance1);
        uint256 gasStart2 = gasleft(); 
        liquidationPool.increasePosition( tstBalance1 / 2, euroBalance1 / 2);
        uint256 gasEnd2 = gasleft();
        vm.stopPrank();

        uint256 gasUsed2 = (gasStart2 - gasEnd2) * tx.gasprice;

        //////// Assert increase in gas cost for 2nd transactions ////////
        
        assertGt(gasUsed2, gasUsed1,"DoS TEST 1");
    }
   
```

</details>


&nbsp;
**Tools Used:**
- Manual review
- Foundry

&nbsp;
**Recommended Mitigation Steps:**
Consider alternative design structures that are more gas-efficient. For example, explore the use of mappings instead of arrays or incorporate the [EnumerableMap library](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/EnumerableMap.sol) by OpenZeppelin.


## [H - 1] `deleteHolder()` Looping Through `holders` Array for Stakers' Positions Poses a Potential Denial of Service (DoS) Attack

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L161



&nbsp;
**Description:**
There is a potential DoS attack risk in the `decreasePosition()` function due to the `deletePosition()` method iterating over unbounded array lengths of `holders` and `pendingStakes`. When a user wants to decrease their position, they call the `decreasePosition()` function, which makes sub-calls down the stack to `deleteHolder()`. This function, in turn, loops through the `holders` array to find the user's position before taking action.Similarly, there is a potential DoS attack risk in the `increasePosition()` function due to the `addUniqueHolder()` method iterating over unbounded array lengths of `holders`, When a user wants to increase their position.


&nbsp;
**Impact:**
If the `holders` array becomes excessively long, leading to an unresponsive state due to an Out of Gas error, users' funds will be permanently locked in the contract. This could mean death for the protocol as new liquidity can't enter the system.

&nbsp;
**Proof of Concept:**  
A malicious actor could disrupt the network by creating numerous addresses and spamming the network with transactions. This could result in the `holders` array becoming too long to iterate over efficiently. Effectively preventing withdrawals.


&nbsp;
**Proof of Code:**

<details><summary>Code</summary>

The provided test suite demonstrates the vulnerability's validity and severity.

### How to Run the Test:
- Due to the file size required to run this PoC, the suite is hosted on Github.
- To run the PoC, clone the repository.
- Minor changes, such as modifying function visibility, were made to enable successful test runs.
- All changes and additional files made to the original code are documented in the README and the respective files where the changes are made.

**Requirements:**
- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html).
- Clone the project codebase into your local workspace.
  ```bash
  git clone https://github.com/Renzo1/the-standard-protocol-2.git
  ```
- Run the following commands to install dependencies:
  ```bash
  npm install
  forge install
  ```
- Run the following command to execute the PoC:
  ```bash
  forge test --match-test "testPositionDecrementDoS" -vvv
  ```

```javascript

    function testPositionDecrementDoS() public {
        vm.txGasPrice(1);

        // //////// Create one vault ////////
        ISmartVault[] memory vaults = new ISmartVault[](20);
        vaults = createVaultOwners(20);

        //////// Owner 1 variables ////////
        ISmartVault vault1 = vaults[0];
        address owner1 = vault1.owner();
        uint256 tstBalance1 = TST.balanceOf(owner1);
        uint256 euroBalance1 = EUROs.balanceOf(owner1);


        //////// Stake Tokens ////////
        vm.warp(block.timestamp + 2 days);

        vm.startPrank(owner1);
        TST.approve(pool, tstBalance1);
        EUROs.approve(pool, euroBalance1);
        liquidationPool.increasePosition( tstBalance1, euroBalance1);
        vm.stopPrank();

        vm.warp(block.timestamp + 2 days);


        //////// Decrease 1st half Position ////////
        vm.startPrank(owner1);
        TST.approve(pool, tstBalance1);
        EUROs.approve(pool, euroBalance1);
        uint256 gasStart1 = gasleft(); // see gas cost for subsequent transaction
        liquidationPool.decreasePosition( tstBalance1 / 2, euroBalance1 / 2);
        uint256 gasEnd1 = gasleft();
        vm.stopPrank();

        uint256 gasUsed1 = (gasStart1 - gasEnd1) * tx.gasprice;


        //////// Add more Holders to liquidationPool ////////

        for(uint256 i = 1; i < vaults.length; i++){

            vm.startPrank(vaults[i].owner());
            TST.approve(pool, tstBalance1);
            EUROs.approve(pool, euroBalance1);
            liquidationPool.increasePosition( 1, 1);
            vm.stopPrank();

        }

        vm.warp(block.timestamp + 2 days);

        //////// Decrease 2nd half Position ////////

        vm.startPrank(owner1);
        TST.approve(pool, tstBalance1);
        EUROs.approve(pool, euroBalance1);
        uint256 gasStart2 = gasleft(); 
        liquidationPool.decreasePosition( tstBalance1 / 2, euroBalance1 / 2);
        uint256 gasEnd2 = gasleft();
        vm.stopPrank();

        uint256 gasUsed2 = (gasStart2 - gasEnd2) * tx.gasprice;

        //////// Assert increase in gas cost for 2nd transactions ////////
        
        assertGt(gasUsed2, gasUsed1,"DoS TEST 1");
    }
```

</details>

&nbsp;
**Tools Used:**
- Manual review
- Foundry

&nbsp;
**Recommended Mitigation Steps:**
Consider alternative design structures that are more gas-efficient. For example, explore the use of mappings instead of arrays or incorporate the [EnumerableMap library](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/EnumerableMap.sol) by OpenZeppelin.




## [M-#] Adding Blacklistable Tokens to Accepted Collateral Assets Can Potentially Cause Loss of Funds for Stakers

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L175C30-L175C30

**Description:**

**Description:**

Some tokens, such as USDC, have a blacklist functionality that allows the admin to block certain addresses from transacting with these tokens. Adding such tokens to the accepted collateral assets will result in some stakers being unable to withdraw their rewards because `claimReward()` fails when called, as the tokens cannot be transferred to them.

**Tools Used:**

- Manual review

**Recommended Mitigation Steps:**

Caution should be applied in selecting assets to use as collateral for EUROs stablecoin. Generally, it is advisable to avoid blacklistable tokens like USDC.


## [L-#] Missing Approval for Protocol to Spend Users' Tokens Causes `increasePosition()` Function to Fail

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L139

**Description:**

When a user calls `LiquidationPool::increasePosition()` to add their position, the function invokes `ERC20::transferFrom()`, which is used to allow a spender to spend funds on behalf of the owner. However, this function requires the owner to pre-approve the spender to spend a specified amount of tokens from their account.

**Impact:**

Poor user experience results from transactions failing without users understanding the reason or how to resolve it. This may contribute to increased user apathy towards the platform.

**Tools Used:**

- Manual review

**Recommended Mitigation Steps:**

Two alternative solutions are available, each with its trade-offs between higher security and improved user experience:

1. Add a `require` statement prompting users to approve the contract to spend the required amount from their account for the transaction to succeed.

2. Set the contract's allowance on users' accounts to a sufficiently large value the first time they use the platform. This way, users won't need to repeat the approval process every time they interact with the protocol.

# [H-1] Insufficient EUROs in LiquidationPool to Buy Liquidated Assets Could Lead to Under-collateralization of EUROs

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L240

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPoolManager.sol#L81C14-L81C14

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPoolManager.sol#L49

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPoolManager.sol#L54


**Description:**

When vaults are liquidated, their collateral is sent to the `LiquidationPool` to be sold for EUROs. If there isn't enough EUROs in the pool to buy these liquidated assets, they are returned back to the `LiquidationPoolManager`, which then forwards them to the protocol's address (i.e., treasury). This implies a delay between the vault liquidation and collateral sell-off to balance the supply of EURO. If the price of these collateral assets falls dramatically during this period, the protocol will have to incur a loss to balance the supply of EUROs.

**Impact:**

Potential loss for the protocol due to a delay in the liquidation process.

**Proof of Concept:**  
Consider the following sequence of actions:

- Vault_1 is minted and supplies 1,000 ETH @ $3,000, i.e., $3,000,000 collateral.
- Owners mint $2,500,000 worth of EUROs.
- Vault is above the liquidation threshold.
- ETH prices drop to $2,600.
- Vault enters the liquidation threshold.
- Vault is liquidated and sent to `LiquidationPool` to be sold.
- The `LiquidationPool` only has $1,000,000 worth of EUROs to buy collateral assets.
- $1,600,000 is sent to the protocol's address (treasury) after selling to the `LiquidationPool`.
- There is a delay between treasury receiving these assets and selling them to buyback and burn EUROs.
- If the price of ETH drops further, the funds recuperated may not be enough to buyback the necessary amount of EUROs to balance its supply.
- Also, the further ETH price drops, the higher the debt gets for the protocol.

**Tools Used:**

- Manual review
- Foundry

**Recommended Mitigation Steps:**

- Constantly monitor the protocol to ensure the Pool is able to support any liquidated amount.
- Further democratize the liquidation process by allowing other network actors, other than the `LiquidationPoolManager`, to be able to liquidate vaults.
- Only send the amount of liquidated asset that the `LiquidationPool` is able to purchase, and send the rest to alternative buyers like the open market or OTC. Just ensure the alternative is a safe option.

# [M-#] Excessive Deployment of Vault Contracts Adds to the Degradation of the Blockchain Network

[Link to Code](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultManagerV5.sol#L86-L87)

**Description:**

When a vault is liquidated, the `SmartVaultManagerV5` revokes the vault's right to burn and mint EURO, rendering it effectively useless. The `MINTER_ROLE()` and `BURNER_ROLE()` roles for EUROs are revoked and not granted back, even if the vaults are recredited. This is akin to rejecting a user from a lending protocol like GMX after they have been liquidated in the past, even if they return with a healthy position — but worse. This practice is wasteful, gas-inefficient, and a net negative for the entire blockchain network, as it introduces garbage data, essentially bloating the network. It is our duty as developers and security researchers to ensure the sanctity and maintenance of the blockchain network if we want to guarantee its sustainability.

**Impact:**

Every liquidated vault contributes to the accumulation of unnecessary data on its host blockchain network, increasing block space demand and consequently costs and centralization.

**Tools Used:**
- Manual review

**Recommended Mitigation Steps:**

Consider alternative design choices for the vault contracts that do not resort to dumping useless data on the blockchain and do not pose a threat to the security of the network.



# [H-3] Lack of Slippage Protection for Users When Swapping Between Collateral Assets Exposes Users to Frontrunning Attacks

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultV3.sol#L217

**Description:**

When users call `swap()` to swap between their collateral, the function makes a sub call to `calculateMinimumAmountOut()`, which returns a value for `minimumAmountOut`. This strategy, commonly employed when interacting with AMM DEXes, ensures that even if a transaction is front-run, it will only execute if the outcome is in the user's favor. However, `calculateMinimumAmountOut()` returns zero when the amount to be swapped doesn't pose a direct risk to the protocol. This means even if the swap is front-run and the `tokenOut` is zero, there will still be sufficient collateral in the vault to back the minted tokens. This leaves users unprotected, as the protocol only shields itself but not its users.

**Impact:**

This could lead to a loss of funds for users and a negative second-order effect on the protocol. The more assets users lose through this attack vector, the lower the total value locked in the protocol, as a consequence of the direct losses and increased apathy toward participating in the network.

**Proof of Concept:**
- John locks $100,000 worth of wBTC and ETH collateral each.
- John has only minted $1000 worth of EUROs.
- John attempts to swap $20,000 worth of wBTC into ETH.
- John's trade is seen in the mem pool by MEV bots with no slippage protection.
- John is frontrunned and gets back $10,000 worth of ETH for his $20,000 worth of wBTC.
- John is disgruntled and rage quits the protocol.
- Other users see or hear of John's situation and leave the platform to protect themselves from becoming victims of such an attack.

**Tools Used:**

- Manual review

**Recommended Mitigation Steps:**

Allow users to set their slippage tolerance but ensure their position can be covered by the swap.

```diff
+ function swap(bytes32 _inToken, bytes32 _outToken, uint256 _amount, uint256 _minimumAmountOut) external onlyOwner {
        uint256 swapFee = _amount * ISmartVaultManagerV3(manager).swapFeeRate() / ISmartVaultManagerV3(manager).HUNDRED_PC();
        address inToken = getSwapAddressFor(_inToken);
-        uint256 minimumAmountOut = calculateMinimumAmountOut(_inToken, _outToken, _amount);
+       uint256 minimumAmountOut = validateMinimumAmountOut(_inToken, _outToken, _amount, _minimumAmountOut);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                tokenIn: inToken,
                tokenOut: getSwapAddressFor(_outToken),
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: _amount - swapFee,
                amountOutMinimum: minimumAmountOut,
                sqrtPriceLimitX96: 0
            });
        inToken == ISmartVaultManagerV3(manager).weth() ?
            executeNativeSwapAndFee(params, swapFee) :
            executeERC20SwapAndFee(params, swapFee);
    }
```
- `validateMinimumAmountOut()` is a hypothetical function that takes in similar parameters as `calculateMinimumAmountOut()` with `_minimumAmountOut` given by the user, to return a value that protects both the user and the protocol.



## [H-1] Misdirection of Liquidated Assets Causes Undercollateralization of EUROs

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultManagerV5.sol#L22

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultV3.sol#L105C115-L105C115

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultV3.sol#L111

**Description:**

When vaults are liquidated, they are intended to be sent to the Liquidator address (i.e., LiquidatorPoolManager) to manage the liquidated assets. However, the vault erroneously sends these assets to the protocol address, which is the treasury. Instances of liquidated assets being directed to the `protocol` instead of the `liquidator` are evident in the following code segments:
- [Liquidated Assets - Lines 105C115 to 105C115](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultV3.sol#L105C115-L105C115)
- [Liquidated Assets - Line 111](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultV3.sol#L111)

To clarify any doubts or confusion about the difference between the `protocol` and `liquidator` addresses, consider the following points:
- The known issues section of the contest document describes the `protocol` address as the treasury address.
["protocol address must be payable and able to handle ERC20s transferred. This address will be set to our Protocol's treasury wallet."](https://www.codehawks.com/contests/clql6lvyu0001mnje1xpqcuvl)
- This [code line](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultManagerV5.sol#L22) clearly states which address is the liquidator. This point is further reinforced by the `onlyLiquidator` modifier.

Misdirection of liquidated assets leads to undercollateralization of EUROs, as assets are not immediately sold to balance the supply of EUROs. When a vault is liquidated, the collateral is sent to the protocol (treasury), instead of the liquidator (LiquidityPoolManager). As a result, these liquidated collateral are not sold immediately to buy back EUROs and burn, leading to undercollateralization of EUROs supply.

**Impact:**

Sending the Liquidated assets to the wrong address implies a delay between when vaults are liquidated and when they are actually sold to buy back and burn EUROs to balance the supply. If the price drops dramatically during this period, it could incur losses for the protocol.

**Proof of Concept:**

For a visual representation of the value flow in the network, [see here]().

**Proof of Code:**

<details><summary>Code</summary>

```javascript
// We use JavaScript instead of Solidity to access JS keywords for formatting.
// Area of focus
@> (int256 swap0, int256 swap1) = _univ3pool.swap();
// ...
```

</details>

**Tools Used:**

- Manual review
- Foundry

**Recommended Mitigation Steps:**

Transfer assets to `liquidator` instead of `protocol`.

```diff

    function liquidateERC20(IERC20 _token) private {
_        if (_token.balanceOf(address(this)) != 0) _token.safeTransfer(ISmartVaultManagerV3(manager).protocol(), _token.balanceOf(address(this)));
+        if (_token.balanceOf(address(this)) != 0) _token.safeTransfer(ISmartVaultManagerV3(manager).protocol(), _token.balanceOf(address(this)));

    }


    function liquidateNative() private {
        if (address(this).balance != 0) {
-            (bool sent,) = payable(ISmartVaultManagerV3(manager).liquidator()).call{value: address(this).balance}("");
+        (bool sent,) = payable(ISmartVaultManagerV3(manager).protocol()).call{value: address(this).balance}("");  
            require(sent, "err-native-liquidate");
       
        }
    }

```

## [H-#] Misdirection of Burn fees to `protocol` Address Instead of `liquidator` Causes Loss of Rewards for Stakers

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultV3.sol#L173
https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultManagerV5.sol#L22


&nbsp;
**Description:**
When users burn EUROs, a small portion is intended to be sent to the Liquidator address (i.e., LiquidatorPoolManager) to manage the liquidated assets. However, the vault erroneously sends these assets to the protocol address, which is the treasury. Instances of liquidated assets being directed to the `protocol` instead of the `liquidator` are evident in the following code segments:
-    [Burn Fees - Line 173](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultV3.sol#L173)


To clarify any doubts or confusion about the difference between the `protocol` and `liquidator` addresses, consider the following points:
- The known issues section of the contest document describes the `protocol` address as the treasury address.
["protocol address must be payable and able to handle ERC20s transferred. This address will be set to our Protocol's treasury wallet."](https://www.codehawks.com/contests/clql6lvyu0001mnje1xpqcuvl)
- This [code line](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultManagerV5.sol#L22) clearly states which address is the liquidator. This point is further reinforced by the `onlyLiquidator` modifier.

&nbsp;
**Impact:**

When fees are sent to the `protocol` instead of the `liquidator`, the stakers receive no rewards, which disincentives them from staking. Although the funds aren't permanently lost, as they can always be sent back to the liquidator, the advantage gained from staking early is lost for early stakers.


&nbsp;
**Proof of Concept:**

For a visual representation of the value flow in the network, [see here]().


&nbsp;
**Proof of Code:**

<details><summary>Code</summary>

```javascript
        //We use javascript instead of solidity to be able to access JS keywords for formatting
        // Area of focus
@>      (int256 swap0, int256 swap1) = _univ3pool.swap()
        // ...
```

</details>

&nbsp;
**Tools Used:**

- Manual review
- Foundry


&nbsp;
**Recommended Mitigation Steps:**

Transfer fees to `liquidator` instead of `protocol`.

```diff
    function burn(uint256 _amount) external ifMinted(_amount) {
        uint256 fee = _amount * ISmartVaultManagerV3(manager).burnFeeRate() / ISmartVaultManagerV3(manager).HUNDRED_PC();
        minted = minted - _amount;
        EUROs.burn(msg.sender, _amount);
-        IERC20(address(EUROs)).safeTransferFrom(msg.sender, ISmartVaultManagerV3(manager).protocol(), fee);
+        IERC20(address(EUROs)).safeTransferFrom(msg.sender, ISmartVaultManagerV3(manager).liquidator(), fee);
        emit EUROsBurned(_amount, fee);
    }
```

## \[H-1\] Misdirection of Mint fees to `protocol` Address Instead of `liquidator` Causes Loss of Rewards for Stakers

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultManagerV5.sol#L22


&nbsp;
**Description:**
When users mint EUROs, a small portion is intended to be sent to the Liquidator address (i.e., LiquidatorPoolManager) to distribute to stakers. However, the vault erroneously sends these fees to the protocol address, which is the treasury. Instances of fees being directed to the `protocol` instead of the `liquidator` are evident in the following code segments:
- [Mint Fees sent to protocol- Line 165](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultV3.sol#L165)


To clarify any doubts or confusion about the difference between the `protocol` and `liquidator` addresses, consider the following points:
- The known issues section of the contest document describes the `protocol` address as the treasury address.
["protocol address must be payable and able to handle ERC20s transferred. This address will be set to our Protocol's treasury wallet."](https://www.codehawks.com/contests/clql6lvyu0001mnje1xpqcuvl)
- This [code line](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultManagerV5.sol#L22) clearly states which address is the liquidator. This point is further reinforced by the `onlyLiquidator` modifier.

&nbsp;
**Impact:**

When fees are sent to the `protocol` instead of the `liquidator`, the stakers receive no rewards, which disincentives them from staking. Although the funds aren't permanently lost, as they can always be sent back to the liquidator, the advantage gained from staking early is lost for early stakers.


&nbsp;
**Proof of Concept:**

For a visual representation of the value flow in the network, [see here]().


&nbsp;
**Proof of Code:**

<details><summary>Code</summary>

```javascript
        //We use javascript instead of solidity to be able to access JS keywords for formatting
        // Area of focus
@>      (int256 swap0, int256 swap1) = _univ3pool.swap()
        // ...
```

</details>

&nbsp;
**Tools Used:**

- Manual review
- Foundry


&nbsp;
**Recommended Mitigation Steps:**

Transfer fees to `liquidator` instead of `protocol`.

```diff
    function mint(address _to, uint256 _amount) external onlyOwner ifNotLiquidated {
        uint256 fee = _amount * ISmartVaultManagerV3(manager).mintFeeRate() / ISmartVaultManagerV3(manager).HUNDRED_PC();
        require(fullyCollateralised(_amount + fee), UNDER_COLL);
        minted = minted + _amount + fee;
        EUROs.mint(_to, _amount);
-        EUROs.mint(ISmartVaultManagerV3(manager).protocol(), fee);
+        EUROs.mint(ISmartVaultManagerV3(manager).protocol(), fee);
        emit EUROsMinted(_to, _amount, fee);
    }
```

## [L-#] Accounting Error Causes `burn()` Function to Revert

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultV3.sol#L169-L175

**Description:**
The `burn()` function reverts when users attempt to burn all the EUROs in their address because the fee supposed to be sent to the `protocol` is burnt along with it. 

**Impact:**
The inability to burn all of one's token in their wallet requires them to burn additional EUROs to fully access their collateral. If every vault requires extra EUROs to be burned to access their collateral, there will be a small portion of collateral locked and unwithdrawable.

**Tools Used:**
- Manual review

**Recommended Mitigation Steps:**
Burn `_amount - fee`, then send the fee.

```diff
-    function burn(uint256 _amount) external ifMinted(_amount) {
-        uint256 fee = _amount * ISmartVaultManagerV3(manager).burnFeeRate() / ISmartVaultManagerV3(manager).HUNDRED_PC();
-        minted = minted - _amount;
-        EUROs.burn(msg.sender, _amount);
-        IERC20(address(EUROs)).safeTransferFrom(msg.sender, ISmartVaultManagerV3(manager).protocol(), fee);
-        emit EUROsBurned(_amount, fee);
    }

// Correct implementation

    function burn(uint256 _amount) external ifMinted(_amount) {
        bool eurApproved = IERC20(EUROs).allowance(msg.sender, address(this)) >= _amount;
        require(eurApproved, "Grant contract allowance");
        uint256 fee = _amount * ISmartVaultManagerV3(manager).burnFeeRate() / ISmartVaultManagerV3(manager).HUNDRED_PC();
        minted = minted - _amount;
        EUROs.burn(msg.sender, _amount - fee);
        (bool success,) = address(EUROs).delegatecall(abi.encodeWithSignature("approve(address,uint256)",address(this),fee));
        require(success, "Delegatecall failed");
        IERC20(address(EUROs)).safeTransferFrom(msg.sender, ISmartVaultManagerV3(manager).liquidator(), fee);
        emit EUROsBurned(_amount, fee);
    }
```


## [L-#] Missing Approval for Protocol to Spend Users' EUROs Tokens Causes `burn()` Function to Fail

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultV3.sol#L173C34-L173C34

**Description:**

When a user calls `SmartVaultV3::burn()` to burn EUROs, the function invokes `ERC20::transferFrom()` to transfer fees, which is used to allow a spender to spend funds on behalf of the owner. However, this function requires the owner to pre-approve the spender to spend a specified amount of tokens from their account.

**Impact:**

Poor user experience results from transactions failing without users understanding the reason or how to resolve it. This may contribute to increased user apathy towards the platform.

**Tools Used:**

- Manual review

**Recommended Mitigation Steps:**

Two alternative solutions are available, each with its trade-offs between higher security and improved user experience:

1. Add a `require` statement prompting users to approve the contract to spend the required amount from their account for the transaction to succeed.

2. Set the contract's allowance on users' accounts to a sufficiently large value the first time they use the platform. This way, users won't need to repeat the approval process every time they interact with the protocol.



## [H-#] `ConsolidatePendingStakes()` Looping Through `pendingStakes` Array for Stakers' Positions Pose a Potential Denial of Service (DoS) Attack


https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L119-L133


**Description:**

Whenever the following functions are called, they make sub-function calls that iterate over the `pendingStakes` array: `LiquidationPool::increasePosition()`, `LiquidationPool::decreasePosition()`, `LiquidationPool::distributeAssets()`, `LiquidationPoolManager::distributeFees()`, `LiquidationPoolManager::runLiquidation()`, and `LiquidationPool::distributeFees()`. These sub-functions, in turn, loop through the `pendingStake` array to find the user's position before taking action.


**Impact:**
If the `pendingStakes` array becomes excessively long, leading to an unresponsive state due to an Out of Gas error, users' funds are at severe risk. The consequences range from loss of funds to the death of the protocol.

**Proof of Concept:**
A malicious actor could disrupt the network by creating numerous addresses and spamming the network with transactions. This could result in the `pendingStakes` array becoming too long to iterate over efficiently, effectively preventing withdrawals.

**Proof of Code:**

<details><summary>Code</summary>

```javascript
// We use JavaScript instead of Solidity to be able to access JS keywords for formatting
// Area of focus
@> (int256 swap0, int256 swap1) = _univ3pool.swap()
// ...
```

</details>

**Tools Used:**

- Manual review
- Foundry

**Recommended Mitigation Steps:**

Consider alternative design structures that are more gas-efficient. For example, explore the use of mappings instead of arrays or incorporate the [EnumerableMap library](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/EnumerableMap.sol) by OpenZeppelin.

## [H-#] `distributeFees()` Looping Through `pendingStakes` Array for Stakers' Positions Pose a Potential Denial of Service (DoS) Attack


https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L182-L195


**Description:**

Whenever the following functions are called, they make sub-function calls that iterate over the `pendingStakes` array: `LiquidationPool::increasePosition()`, `LiquidationPool::decreasePosition()`, `LiquidationPool::distributeAssets()`, `LiquidationPoolManager::distributeFees()`, `LiquidationPoolManager::runLiquidation()`, and `LiquidationPool::distributeFees()`. These sub-functions, in turn, loop through the `pendingStake` array to find the user's position before taking action.


**Impact:**
If the `pendingStakes` array becomes excessively long, leading to an unresponsive state due to an Out of Gas error, users' funds are at severe risk. The consequences range from loss of funds to the death of the protocol.

**Proof of Concept:**
A malicious actor could disrupt the network by creating numerous addresses and spamming the network with transactions. This could result in the `pendingStakes` array becoming too long to iterate over efficiently, effectively preventing withdrawals.

**Proof of Code:**

**Proof of Code:**

<details><summary>Code</summary>

The provided test suite demonstrates the vulnerability's validity and severity.

### How to Run the Test:
- Due to the file size required to run this PoC, the suite is hosted on Github.
- To run the PoC, clone the repository.
- Minor changes, such as modifying function visibility, were made to enable successful test runs.
- All changes and additional files made to the original code are documented in the README and the respective files where the changes are made.

**Requirements:**
- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html).
- Clone the project codebase into your local workspace.
  ```bash
  git clone https://github.com/Renzo1/the-standard-protocol-2.git
  ```
- Run the following commands to install dependencies:
  ```bash
  npm install
  forge install
  ```
- Run the following command to execute the PoC:
  ```bash
  forge test --match-test "testFeeDistributionDoS" -vvv
  ```

```javascript


    function testFeeDistributionDoS() public {
        vm.txGasPrice(1);

        // //////// Create one vault ////////
        ISmartVault[] memory vaults0 = new ISmartVault[](1);
        vaults0 = createVaultOwners(1);

        //////// Owner 1 variables ////////
        ISmartVault vault1 = vaults0[0];
        address owner1 = vault1.owner();
        uint256 tstBalance1 = TST.balanceOf(owner1);
        uint256 euroBalance1 = EUROs.balanceOf(owner1);


        //////// Stake Tokens -- create holder ////////
        vm.warp(block.timestamp + 2 days);

        vm.startPrank(owner1);
        TST.approve(pool, tstBalance1);
        EUROs.approve(pool, euroBalance1);
        liquidationPool.increasePosition( tstBalance1/4, euroBalance1/4);
        EUROs.transfer(liquidationPoolManager, tstBalance1/4);
        vm.stopPrank();

        assertEq(EUROs.balanceOf(liquidationPoolManager),tstBalance1/4);

        //////// Distribute fees ////////
        uint256 gasStart1 = gasleft(); // see gas cost for subsequent transaction
        liquidationPoolManagerContract.distributeFees();
        uint256 gasEnd1 = gasleft();


        vm.warp(block.timestamp + 2 days); // clear pendingStakes

        uint256 gasUsed1 = (gasStart1 - gasEnd1) * tx.gasprice;

        //////// Add more holders to liquidationPool ////////
        ISmartVault[] memory vaults = new ISmartVault[](20);
        vaults = createVaultOwners(20);

        for(uint256 i = 0; i < vaults.length; i++){
            vm.startPrank(vaults[i].owner());
            TST.approve(pool, tstBalance1);
            EUROs.approve(pool, euroBalance1);
            liquidationPool.increasePosition( 1000, 1000);
            vm.stopPrank();
        }

        //////// Distribute fees again ////////
        vm.startPrank(owner1);
        EUROs.transfer(liquidationPoolManager, tstBalance1/4);
        vm.stopPrank();

        assertGt(EUROs.balanceOf(liquidationPoolManager), 0);

        uint256 gasStart2 = gasleft(); // see gas cost for subsequent transaction
        liquidationPoolManagerContract.distributeFees();
        uint256 gasEnd2 = gasleft();

        uint256 gasUsed2 = (gasStart2 - gasEnd2) * tx.gasprice;

        //////// Assert increase in gas cost for 2nd transactions ////////
        assertGt(gasUsed2, gasUsed1,"DoS TEST 1");
    }
   
```

</details>

**Tools Used:**

- Manual review
- Foundry

**Recommended Mitigation Steps:**

Consider alternative design structures that are more gas-efficient. For example, explore the use of mappings instead of arrays or incorporate the [EnumerableMap library](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/EnumerableMap.sol) by OpenZeppelin.


## [H-#] `getTstTotal()` Looping Through `pendingStakes` Array for Stakers' Positions Pose a Potential Denial of Service (DoS) Attack


https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L55-L62


**Description:**

Whenever the following functions are called, they make sub-function calls that iterate over the `pendingStakes` array: `LiquidationPool::increasePosition()`, `LiquidationPool::decreasePosition()`, `LiquidationPool::distributeAssets()`, `LiquidationPoolManager::distributeFees()`, `LiquidationPoolManager::runLiquidation()`, and `LiquidationPool::distributeFees()`. These sub-functions, in turn, loop through the `pendingStake` array to find the user's position before taking action.


**Impact:**
If the `pendingStakes` array becomes excessively long, leading to an unresponsive state due to an Out of Gas error, users' funds are at severe risk. The consequences range from loss of funds to the death of the protocol.

**Proof of Concept:**
A malicious actor could disrupt the network by creating numerous addresses and spamming the network with transactions. This could result in the `pendingStakes` array becoming too long to iterate over efficiently, effectively preventing withdrawals.

**Proof of Code:**

<details><summary>Code</summary>

The provided test suite demonstrates the vulnerability's validity and severity.

### How to Run the Test:
- Due to the file size required to run this PoC, the suite is hosted on Github.
- To run the PoC, clone the repository.
- Minor changes, such as modifying function visibility, were made to enable successful test runs.
- All changes and additional files made to the original code are documented in the README and the respective files where the changes are made.

**Requirements:**
- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html).
- Clone the project codebase into your local workspace.
  ```bash
  git clone https://github.com/Renzo1/the-standard-protocol-2.git
  ```
- Run the following commands to install dependencies:
  ```bash
  npm install
  forge install
  ```
- Run the following command to execute the PoC:
  ```bash
  forge test --match-test "testFeeDistributionDoS" -vvv
  ```

```javascript


    function testFeeDistributionDoS() public {
        vm.txGasPrice(1);

        // //////// Create one vault ////////
        ISmartVault[] memory vaults0 = new ISmartVault[](1);
        vaults0 = createVaultOwners(1);

        //////// Owner 1 variables ////////
        ISmartVault vault1 = vaults0[0];
        address owner1 = vault1.owner();
        uint256 tstBalance1 = TST.balanceOf(owner1);
        uint256 euroBalance1 = EUROs.balanceOf(owner1);


        //////// Stake Tokens -- create holder ////////
        vm.warp(block.timestamp + 2 days);

        vm.startPrank(owner1);
        TST.approve(pool, tstBalance1);
        EUROs.approve(pool, euroBalance1);
        liquidationPool.increasePosition( tstBalance1/4, euroBalance1/4);
        EUROs.transfer(liquidationPoolManager, tstBalance1/4);
        vm.stopPrank();

        assertEq(EUROs.balanceOf(liquidationPoolManager),tstBalance1/4);

        //////// Distribute fees ////////
        uint256 gasStart1 = gasleft(); // see gas cost for subsequent transaction
        liquidationPoolManagerContract.distributeFees();
        uint256 gasEnd1 = gasleft();


        vm.warp(block.timestamp + 2 days); // clear pendingStakes

        uint256 gasUsed1 = (gasStart1 - gasEnd1) * tx.gasprice;

        //////// Add more holders to liquidationPool ////////
        ISmartVault[] memory vaults = new ISmartVault[](20);
        vaults = createVaultOwners(20);

        for(uint256 i = 0; i < vaults.length; i++){
            vm.startPrank(vaults[i].owner());
            TST.approve(pool, tstBalance1);
            EUROs.approve(pool, euroBalance1);
            liquidationPool.increasePosition( 1000, 1000);
            vm.stopPrank();
        }

        //////// Distribute fees again ////////
        vm.startPrank(owner1);
        EUROs.transfer(liquidationPoolManager, tstBalance1/4);
        vm.stopPrank();

        assertGt(EUROs.balanceOf(liquidationPoolManager), 0);

        uint256 gasStart2 = gasleft(); // see gas cost for subsequent transaction
        liquidationPoolManagerContract.distributeFees();
        uint256 gasEnd2 = gasleft();

        uint256 gasUsed2 = (gasStart2 - gasEnd2) * tx.gasprice;

        //////// Assert increase in gas cost for 2nd transactions ////////
        assertGt(gasUsed2, gasUsed1,"DoS TEST 1");
    }
   
```

</details>

**Tools Used:**

- Manual review
- Foundry

**Recommended Mitigation Steps:**

Consider alternative design structures that are more gas-efficient. For example, explore the use of mappings instead of arrays or incorporate the [EnumerableMap library](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/EnumerableMap.sol) by OpenZeppelin.

## [H-#] Misdirection of ERC20 Native Swap fees to `protocol` Address Instead of `liquidator` Causes Loss of Rewards for Stakers


https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultV3.sol#L196-L204

**Description:**
When users swap EUROs, a small fee is intended to be sent to the `SmartVaultManagerV5::liquidator` address (i.e., LiquidatorPoolManager) to distribute to stakers. However, the vault erroneously sends these fees to the `SmartVaultManagerV5::protocol` address, which is the treasury. Instances of fees being directed to the `SmartVaultManagerV5::protocol` instead of the `SmartVaultManagerV5::liquidator` are evident in the following code segments:
- [Swap Fees sent to protocol- Line 165](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultV3.sol#L190-L195)
- [Swap Fees sent to protocol- Line 165](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultV3.sol#L196-L204)

To clarify any doubts or confusion about the difference between the `protocol` and `liquidator` addresses, consider the following points:
- The known issues section of the contest document describes the `protocol` address as the treasury address.
["protocol address must be payable and able to handle ERC20s transferred. This address will be set to our Protocol's treasury wallet."](https://www.codehawks.com/contests/clql6lvyu0001mnje1xpqcuvl)
- This [code line](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultManagerV5.sol#L22) clearly states which address is the liquidator. This point is further reinforced by the `onlyLiquidator` modifier.

&nbsp;
**Impact:**

When fees are sent to the `protocol` instead of the `liquidator`, the stakers receive no rewards, which disincentives them from staking. Although the funds aren't permanently lost, as they can always be sent back to the liquidator, the advantage gained from staking early is lost for early stakers.


&nbsp;
**Proof of Concept:**

For a visual representation of the value flow in the network, [see here]().


&nbsp;
**Proof of Code:**

<details><summary>Code</summary>

```javascript
        //We use javascript instead of solidity to be able to access JS keywords for formatting
        // Area of focus
@>      (int256 swap0, int256 swap1) = _univ3pool.swap()
        // ...
```

</details>

&nbsp;
**Tools Used:**

- Manual review
- Foundry


&nbsp;
**Recommended Mitigation Steps:**

Transfer fees to `liquidator` instead of `protocol`.

```diff
function executeERC20SwapAndFee(ISwapRouter.ExactInputSingleParams memory _params, uint256 _swapFee) private {
-        IERC20(_params.tokenIn).safeTransfer(ISmartVaultManagerV3(manager).protocol(), _swapFee);
+        IERC20(_params.tokenIn).safeTransfer(ISmartVaultManagerV3(manager).liquidator(), _swapFee);
        IERC20(_params.tokenIn).safeApprove(ISmartVaultManagerV3(manager).swapRouter2(), _params.amountIn);
        ISwapRouter(ISmartVaultManagerV3(manager).swapRouter2()).exactInputSingle(_params);
        IWETH weth = IWETH(ISmartVaultManagerV3(manager).weth());
        // convert potentially received weth to eth
        uint256 wethBalance = weth.balanceOf(address(this));
        if (wethBalance > 0) weth.withdraw(wethBalance);
    }

```

## [H-1] Misdirection of Native Swap fees to `protocol` Address Instead of `liquidator` Causes Loss of Rewards for Stakers

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultV3.sol#L190-L195


**Description:**
When users swap EUROs, a small fee is intended to be sent to the `SmartVaultManagerV5::liquidator` address (i.e., LiquidatorPoolManager) to distribute to stakers. However, the vault erroneously sends these fees to the `SmartVaultManagerV5::protocol` address, which is the treasury. Instances of fees being directed to the `SmartVaultManagerV5::protocol` instead of the `SmartVaultManagerV5::liquidator` are evident in the following code segments:
- [Swap Fees sent to protocol- Line 165](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultV3.sol#L190-L195)
- [Swap Fees sent to protocol- Line 165](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultV3.sol#L196-L204)

To clarify any doubts or confusion about the difference between the `protocol` and `liquidator` addresses, consider the following points:
- The known issues section of the contest document describes the `protocol` address as the treasury address.
["protocol address must be payable and able to handle ERC20s transferred. This address will be set to our Protocol's treasury wallet."](https://www.codehawks.com/contests/clql6lvyu0001mnje1xpqcuvl)
- This [code line](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/SmartVaultManagerV5.sol#L22) clearly states which address is the liquidator. This point is further reinforced by the `onlyLiquidator` modifier.

&nbsp;
**Impact:**

When fees are sent to the `protocol` instead of the `liquidator`, the stakers receive no rewards, which disincentives them from staking. Although the funds aren't permanently lost, as they can always be sent back to the liquidator, the advantage gained from staking early is lost for early stakers.


&nbsp;
**Proof of Concept:**

For a visual representation of the value flow in the network, [see here]().


&nbsp;
**Proof of Code:**

<details><summary>Code</summary>

```javascript
        //We use javascript instead of solidity to be able to access JS keywords for formatting
        // Area of focus
@>      (int256 swap0, int256 swap1) = _univ3pool.swap()
        // ...
```

</details>

&nbsp;
**Tools Used:**

- Manual review
- Foundry


&nbsp;
**Recommended Mitigation Steps:**

Transfer fees to `liquidator` instead of `protocol`.

```diff
    function executeNativeSwapAndFee(ISwapRouter.ExactInputSingleParams memory _params, uint256 _swapFee) private {
-        (bool sent,) = payable(ISmartVaultManagerV3(manager).protocol()).call{value: _swapFee}("");
+        (bool sent,) = payable(ISmartVaultManagerV3(manager).protocol()).call{value: _swapFee}("");
        require(sent, "err-swap-fee-native");
        ISwapRouter(ISmartVaultManagerV3(manager).swapRouter2()).exactInputSingle{value: _params.amountIn}(_params);
    }
```


## [H-#] Unchecked Transfer in claimReward() Could Cause Loss of Reward

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L175

**Description:**

When a staker calls `claimReward()` to withdraw their reward, it is sent to them with `IERC20::transfer` function. However, the return value of an external transfer call in `claimReward()` is not checked.

**Impact:**

Any transaction to `msg.caller` that fails will fail silently, which could lead to a loss for the caller.

**Tools Used:**

- Slither

**Recommended Mitigation Steps:**

Use `SafeERC20`, or ensure that the `transfer` return value is checked.


## [H-#] Division Before Multiply.

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L220-L221

&nbsp;
**Description:**

Solidity's integer division truncates. Thus, performing division before multiplication can lead to precision loss.

&nbsp;
**Impact:**

This could lead to internal accounting errors.



&nbsp;
**Tools Used:**

- Slither

&nbsp;
**Recommended Mitigation Steps:**
Consider ordering multiplication before division.


## [H-1] Unchecked Transfer in forwardRemainingRewards() Could Cause Loss for the Protocol

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPoolManager.sol#L54

**Description:**

After the liquidated assets in `LiquidationPoolManager` is sold to the LiquidationPool, any amount unsold to the pool is forward from the `LiquidationPoolManager` to address `protocol` (treasury), using `IERC20::transfer` in `forwardRemainingRewards()` function. However, the return value of an external transfer call in `forwardRemainingRewards()` is not checked.

**Impact:**

Any delay in sending these tokens, implies a delay for the liquidated asset to be sold, which puts EUROs at risk of undercollateralization.

**Tools Used:**

- Slither

**Recommended Mitigation Steps:**

Use `SafeERC20`, or ensure that the `transfer` return value is checked.


## [H-#] Unchecked Transfer in `LiquidationPoolManager::distributeFees()` Could Cause Loss for the Protocol

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPoolManager.sol#L40

**Description:**

`LiquidationPoolManager::distributeFees()` is called periodically to distribute fees to network stakers and the protocol treasury. The treasury's share is sent using the `ERC20::transfer` function. However, the return value of an external transfer call in `distributeFee()` is not checked.

**Impact:**

If the transaction fails, it fails silently, causing the protocol to miss out on its share of the reward. The next `distributeFees()` call shares all the fees in the pool between both groups.

**Tools Used:**

- Slither

**Recommended Mitigation Steps:**

Use `SafeERC20`, or ensure that the `transfer` return value is checked.


## [H-#] `LiquidationPoolManager::distributeAssets()` Uses Deprecated Chainlink Function to Calculate `assetPriceFeed`

[GitHub Link to the Code](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L218C114-L218C114)

**Description:**

The usage of deprecated Chainlink functions, such as `latestRoundData()`, might return stale or incorrect data, affecting the integrity of smart contracts. [See here](https://github.com/code-423n4/2022-04-backd-findings/issues/17).

**Impact:**

If the price feed is inaccurate, the value for `assetPriceUsd` will be inaccurate, potentially causing overpricing or underpricing of assets, leading to a loss for either the protocol or stakers.

**Proof of Concept:**

- [ChainlinkOracleProvider.sol#L55](https://github.com/code-423n4/2022-04-backd/blob/main/backd/contracts/oracles/ChainlinkOracleProvider.sol#L55)
- [ChainlinkUsdWrapper.sol#L64](https://github.com/code-423n4/2022-04-backd/blob/main/backd/contracts/oracles/ChainlinkUsdWrapper.sol#L64)

**Tools Used:**

- Manual review

**Recommended Mitigation Steps:**

Use the `latestRoundData` function to retrieve the price. Add checks on the return data with proper revert messages if the price is stale or the round is incomplete. For example:
```solidity
(uint80 roundID, int256 assetPriceFeed, , uint256 timeStamp, uint80 answeredInRound) = oracle.latestRoundData();
require(answeredInRound >= roundID, "...");
require(timeStamp != 0, "...");
```

## [H-#] `LiquidationPoolManager::distributeAssets()` Uses Deprecated Chainlink Function to Calculate `priceEurUsd`

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L207

**Description:**

The usage of deprecated Chainlink functions, such as `latestRoundData()`, might return stale or incorrect data, affecting the integrity of smart contracts. [See here](https://github.com/code-423n4/2022-04-backd-findings/issues/17).

**Impact:**

If the price feed is inaccurate, the value for `priceEurUsd` will be inaccurate, potentially causing overpricing or underpricing of assets, leading to a loss for either the protocol or stakers.

**Proof of Concept:**

- [ChainlinkOracleProvider.sol#L55](https://github.com/code-423n4/2022-04-backd/blob/main/backd/contracts/oracles/ChainlinkOracleProvider.sol#L55)
- [ChainlinkUsdWrapper.sol#L64](https://github.com/code-423n4/2022-04-backd/blob/main/backd/contracts/oracles/ChainlinkUsdWrapper.sol#L64)

**Tools Used:**

- Manual review

**Recommended Mitigation Steps:**

Use the `latestRoundData` function to retrieve the price. Add checks on the return data with proper revert messages if the price is stale or the round is incomplete. For example:
```solidity
(uint80 roundID, int256 priceEurUsd, , uint256 timeStamp, uint80 answeredInRound) = Chainlink.AggregatorV3Interface(eurUsd).latestRoundData();
require(answeredInRound >= roundID, "...");
require(timeStamp != 0, "...");
```

## [M-#] Lack of Validation to Check if the Rollup Sequence Is Running

https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L205-L242

**Description:**

Arbitrium, as a layer 2 rollup network, moves all execution off the layer 1 (L1) Ethereum chain, completes execution on its chain, and returns the results of the L2 execution back to the L1. This protocol has a sequencer that executes and rolls up the L2 transactions by batching multiple transactions into a single transaction.

If a sequencer becomes unavailable, it is impossible to access read APIs, such as the Chainlink oracle price feed. This could throw off the price-reliant functions in the contract, for example, `LiquidationPool::distributeAssets()`.

**Impact:**

The rollup sequencer can become offline, potentially leading to vulnerabilities due to stale prices.

**Tools Used:**

- Manual review

**Recommended Mitigation Steps:**

To identify when the sequencer is unavailable, you can use a data feed that tracks the last known status of the sequencer at a given point in time. [See here](https://docs.chain.link/data-feeds/l2-sequencer-feeds)


## [M-#] Unanticipated Oracle Reverts Can Lead to Denial-Of-Service

[GitHub Link to the Code](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L205-L242)

**Description:**

In a rare occasion where the Chainlink oracle contract might revert, the `LiquidityPool::distributeAssets()` becomes unresponsive and consistently so.

**Impact:**

This can lead to undercollateralization of EUROs as liquidated assets aren't immediately sold to balance EUROs supply.

**Tools Used:**

- Manual review

**Recommended Mitigation Steps:**

Implement try/catch blocks around oracle calls and have alternative strategies ready.


## [M-#] `LiquidationPool` Assumes Every Address Can Accept Ether, Leading to Loss of Stakers' Rewards

[GitHub Link to the Code](Link to your GitHub code)

**Description:**

When users call `LiquidationPool::claimRewards()` to claim their rewards from the pool, the contract attempts to send them their ERC20 and native token rewards at once. However, not all addresses can receive native tokens like ETH, for example, contracts without a `receive()` or `fallback()` function. As a result, this function fails every time such a user calls it.

**Impact:**

Users' rewards are permanently locked in the contract, as no one can withdraw them on their behalf.

**Tools Used:**

- Manual review

**Recommended Mitigation Steps:**

Whenever a transfer of native tokens like ETH fails, wrap it and send it as ERC20 to the same address.


```diff

+        function _handleOutgoingNativeTransfer(address _to, uint256 _amount) private {
+                // Validate the contract has enough ETH to transfer
+                if (address(this).balance < _amount) revert INSUFFICIENT_BALANCE();
+
+                bool success;
+                (bool _sent,) = payable(msg.sender).call{value: _rewardAmount}("");
+                
+                if (!_sent){
+                        IWETH(WETH).deposit{value: _amount}();
+                        bool success = IWETH(WETH).transfer(_to, _amount);
+
+                        // Ensure successful tranfer
+                        if (!success){
+                                revert FAILING_WETH_TRANSFER();
+                        }
+                }
+        }


    function claimRewards() external {
        ITokenManager.Token[] memory _tokens = ITokenManager(tokenManager).getAcceptedTokens();
        for (uint256 i = 0; i < _tokens.length; i++) {
            ITokenManager.Token memory _token = _tokens[i];
            uint256 _rewardAmount = rewards[abi.encodePacked(msg.sender, _token.symbol)];
            if (_rewardAmount > 0) {
                delete rewards[abi.encodePacked(msg.sender, _token.symbol)];
                if (_token.addr == address(0)) {
-                    (bool _sent,) = payable(msg.sender).call{value: _rewardAmount}("");
-                    require(_sent);
+                     _handleOutgoingNativeTransfer(payable(msg.sender), _rewardAmount)        
                } else {
                    IERC20(_token.addr).transfer(msg.sender, _rewardAmount);
                }   
            }

        }
    }

```

## [M-#] Inadequate Validation for Chainlink Oracle

[GitHub Link to the Code](https://github.com/Cyfrin/2023-12-the-standard/blob/91132936cb09ef9bf82f38ab1106346e2ad60f91/contracts/LiquidationPool.sol#L205-L242)

**Description:**

LiquidationPool relies on Chainlink's price feed to assess the value of assets distributed to stakers. However, these prices lack sufficient validation. There is no freshness check on the timestamp of the prices, allowing the usage of outdated prices if [OCR](https://docs.chain.link/architecture-overview/off-chain-reporting) fails to provide an update in time.

**Impact:**

Outdated prices result in stakers receiving incorrect valuations for liquidated assets. This leads to stakers receiving more or less than they should, impacting the overall network.

**Proof of Concept:**

The timestamp field is disregarded, leaving no means to verify whether the price is recent enough:

```javascript
function distributeAssets(ILiquidationPoolManager.Asset[] memory _assets, uint256 _collateralRate, uint256 _hundredPC) external payable {
    consolidatePendingStakes();
@>    (,int256 priceEurUsd,,,) = Chainlink.AggregatorV3Interface(eurUsd).latestRoundData();
    ...
    if (asset.amount > 0) {
@>        (,int256 assetPriceUsd,,,) = Chainlink.AggregatorV3Interface(asset.token.clAddr).latestRoundData();
    ...
}
```

**Tools Used:**

- Manual review

**Recommended Mitigation Steps:**

Introduce a configuration parameter for the staleness threshold in seconds and ensure that the fetched price falls within that time range.
