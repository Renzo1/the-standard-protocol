// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/interfaces/INFTMetadataGenerator.sol";
import "contracts/interfaces/IEUROs.sol";
import "contracts/interfaces/ISmartVault.sol";
import "contracts/interfaces/ISmartVaultDeployer.sol";
import "contracts/interfaces/ISmartVaultIndex.sol";
import "contracts/interfaces/ISmartVaultManager.sol";
import "contracts/interfaces/ISmartVaultManagerV2.sol";

contract SmartVaultManagerV5 is ISmartVaultManager, ISmartVaultManagerV2, Initializable, ERC721Upgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    
    uint256 public constant HUNDRED_PC = 1e5;

    // @q how are these variables set?
    address public protocol; // @q who or what contract is this? Ans: Protocol's treasury wallet.
    address public liquidator; // @q who is the liquidator? Ans: LiquidationPoolManager
    address public euros;
    uint256 public collateralRate;
    address public tokenManager;
    address public smartVaultDeployer;
    ISmartVaultIndex private smartVaultIndex;
    uint256 private lastToken;
    address public nftMetadataGenerator;
    uint256 public mintFeeRate;
    uint256 public burnFeeRate;
    uint256 public swapFeeRate;
    address public weth;
    address public swapRouter;
    address public swapRouter2;

    event VaultDeployed(address indexed vaultAddress, address indexed owner, address vaultType, uint256 tokenId);
    event VaultLiquidated(address indexed vaultAddress);
    event VaultTransferred(uint256 indexed tokenId, address from, address to);

    struct SmartVaultData { 
        uint256 tokenId; uint256 collateralRate; uint256 mintFeeRate;
        uint256 burnFeeRate; ISmartVault.Status status;
    }

    function initialize() initializer public {}

    modifier onlyLiquidator {
        require(msg.sender == liquidator, "err-invalid-liquidator");
        _;
    }

    function vaults() external view returns (SmartVaultData[] memory) {
        uint256[] memory tokenIds = smartVaultIndex.getTokenIds(msg.sender);
        uint256 idsLength = tokenIds.length;
        SmartVaultData[] memory vaultData = new SmartVaultData[](idsLength);
        // @audit iterated over an unbounded array. Potential DoS // Known Issue
        for (uint256 i = 0; i < idsLength; i++) {
            uint256 tokenId = tokenIds[i];
            vaultData[i] = SmartVaultData({
                tokenId: tokenId,
                collateralRate: collateralRate,
                mintFeeRate: mintFeeRate,
                burnFeeRate: burnFeeRate,
                status: ISmartVault(smartVaultIndex.getVaultAddress(tokenId)).status()
            });
        }
        return vaultData;
    }

    // @note: create a vault
    function mint() external returns (address vault, uint256 tokenId) {
        tokenId = lastToken + 1;
        _safeMint(msg.sender, tokenId);
        lastToken = tokenId;
        vault = ISmartVaultDeployer(smartVaultDeployer).deploy(address(this), msg.sender, euros);
        smartVaultIndex.addVaultAddress(tokenId, payable(vault));
        IEUROs(euros).grantRole(IEUROs(euros).MINTER_ROLE(), vault);
        IEUROs(euros).grantRole(IEUROs(euros).BURNER_ROLE(), vault);
        emit VaultDeployed(vault, msg.sender, euros, tokenId);
    }

    // @audit inspect this logic flow again
    // when a vault is liquidated, it is rendered useless.
    // their MINTER_ROLE() and BURNER_ROLE() roles for EUROs are revoked
    // But its not granted back, when the vault are reCredited
    // Gas efficiency? Blockchain bloating? Unnecessary deployment?
    // This is wasteful. It's equivalent of saying a lending protocol user
    // can never use a platform once they've been liquidated,
    // even if they return with a healthy position
    // @Test Liquate a vault, refund it, and try to mint new tokens
    function liquidateVault(uint256 _tokenId) external onlyLiquidator {
        ISmartVault vault = ISmartVault(smartVaultIndex.getVaultAddress(_tokenId)); // get the vault to be liquidated by token Id
        try vault.undercollateralised() returns (bool _undercollateralised) { // check if vault is undercollateralized
            require(_undercollateralised, "vault-not-undercollateralised"); // if vault is undercollateralized, continue
            vault.liquidate(); // liquidate vault
            IEUROs(euros).revokeRole(IEUROs(euros).MINTER_ROLE(), address(vault)); // revoke vault minter role
            IEUROs(euros).revokeRole(IEUROs(euros).BURNER_ROLE(), address(vault)); // revoke vault minter role
            emit VaultLiquidated(address(vault));
        } catch {
            revert("other-liquidation-error");
        }
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        ISmartVault.Status memory vaultStatus = ISmartVault(smartVaultIndex.getVaultAddress(_tokenId)).status();
        return INFTMetadataGenerator(nftMetadataGenerator).generateNFTMetadata(_tokenId, vaultStatus);
    }

    function totalSupply() external view returns (uint256) {
        return lastToken;
    }

    function setMintFeeRate(uint256 _rate) external onlyOwner {
        mintFeeRate = _rate;
    }

    function setBurnFeeRate(uint256 _rate) external onlyOwner {
        burnFeeRate = _rate;   
    }

    function setSwapFeeRate(uint256 _rate) external onlyOwner {
        swapFeeRate = _rate;
    }

    function setWethAddress(address _weth) external onlyOwner() {
        weth = _weth;
    }

    function setSwapRouter2(address _swapRouter) external onlyOwner() {
        swapRouter2 = _swapRouter;
    }

    function setNFTMetadataGenerator(address _nftMetadataGenerator) external onlyOwner() {
        nftMetadataGenerator = _nftMetadataGenerator;
    }

    function setSmartVaultDeployer(address _smartVaultDeployer) external onlyOwner() {
        smartVaultDeployer = _smartVaultDeployer;
    }

    function setProtocolAddress(address _protocol) external onlyOwner() {
        protocol = _protocol;
    }

    function setLiquidatorAddress(address _liquidator) external onlyOwner() {
        liquidator = _liquidator;
    }

    // @q where is this called from?
    function _afterTokenTransfer(address _from, address _to, uint256 _tokenId, uint256) internal override {
        smartVaultIndex.transferTokenId(_from, _to, _tokenId);
        if (address(_from) != address(0)) ISmartVault(smartVaultIndex.getVaultAddress(_tokenId)).setOwner(_to);
        emit VaultTransferred(_tokenId, _from, _to);
    }
}