// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "solady/auth/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

struct OrderFees {
    uint256 fixedFees;
    uint256 utilizationFees;
    int256 skewFees;
    int256 wrapperFees;
}

interface IFeeCollector is IERC165 {
    /**
     * @notice  .This function is called by the spot market proxy to get the fee amount to be collected.
     * @dev     .The quoted fee amount is then transferred directly to the fee collector.
     * @param   marketId  .synth market id value
     * @param   feeAmount  .max fee amount that can be collected
     * @param   transactor  .the trader the fee was collected from
     * @return  feeAmountToCollect  .quoted fee amount
     */
    function quoteFees(uint128 marketId, uint256 feeAmount, address transactor)
        external
        returns (uint256 feeAmountToCollect);
}

interface SpotMarket {
    function unwrap(uint128 marketId, uint256 unwrapAmount, uint256 minAmountReceived)
        external
        returns (uint256 returnCollateralAmount, OrderFees memory fees);

    function buy(uint128 marketId, uint256 usdAmount, uint256 minAmountReceived, address referrer)
        external
        returns (uint256 synthAmount, OrderFees memory fees);
}

interface TokenMessenger {
    function depositForBurn(uint256 amount, uint32 destinationDomain, bytes32 mintRecipient, address burnToken)
        external
        returns (uint64 _nonce);
}

contract USDCSenderFromBase is Ownable, IFeeCollector {
    // SYNTHETIX TOKEN AND CONTRACT
    IERC20 public constant sUSDC = IERC20(0xC74eA762cF06c9151cE074E6a569a5945b6302E7);
    IERC20 public constant snxUSD = IERC20(0x09d51516F38980035153a554c26Df3C6f51a23C3);
    SpotMarket public constant SPOT_MARKET = SpotMarket(0x18141523403e2595D31b22604AcB8Fc06a4CaA61);
    uint256 public immutable snxFeeShare;

    // CCTP CONFIGURATION
    IERC20 public constant USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    TokenMessenger public constant TOKEN_MESSENGER = TokenMessenger(0x1682Ae6375C4E4A97e4B583BC394c861A46D8962);
    uint32 public destinationDomain;
    bytes32 public destinationAddress;

    uint128 public minimumBalanceD6;
    uint128 public bountyD6;

    constructor(
        address _owner,
        uint32 _destinationDomain,
        address _destinationAddress,
        uint128 _minimumBalanceD6,
        uint128 _bountyD6,
        uint256 _snxFeeShare
    ) {
        require(_minimumBalanceD6 > _bountyD6, "bounty must be smaller than balance to send");
        _initializeOwner(_owner);
        destinationDomain = _destinationDomain;
        destinationAddress = addressToBytes32(_destinationAddress);
        minimumBalanceD6 = _minimumBalanceD6;
        bountyD6 = _bountyD6;
        snxFeeShare = _snxFeeShare;
        snxUSD.approve(address(SPOT_MARKET), type(uint256).max);
        sUSDC.approve(address(SPOT_MARKET), type(uint256).max);
        USDC.approve(address(TOKEN_MESSENGER), type(uint256).max);
    }

    function send() external {
        uint256 balanceD18 = snxUSD.balanceOf(address(this));
        balanceD18 = balanceD18 - (balanceD18 % 1e12);
        SPOT_MARKET.buy(1, balanceD18, balanceD18, address(0));
        (uint256 balanceD6,) = SPOT_MARKET.unwrap(1, balanceD18, 0);
        require(balanceD6 > minimumBalanceD6, "not enough USDC");
        USDC.transfer(msg.sender, bountyD6);
        TOKEN_MESSENGER.depositForBurn(balanceD6 - bountyD6, destinationDomain, destinationAddress, address(USDC));
    }

    function setDestination(uint32 _newDomain, address _newAddress) external onlyOwner {
        destinationDomain = _newDomain;
        destinationAddress = addressToBytes32(_newAddress);
    }

    function setMinimumBalance(uint128 _newMinimumBalanceD6, uint128 _newBountyD6) external onlyOwner {
        require(_newMinimumBalanceD6 > _newBountyD6);
        minimumBalanceD6 = _newMinimumBalanceD6;
        bountyD6 = _newBountyD6;
    }

    function recoverERC20(address _token) external onlyOwner {
        SafeTransferLib.safeTransferAll(_token, owner());
    }

    function quoteFees(uint128 marketId, uint256 feeAmount, address sender) external view override returns (uint256) {
        // mention the variables in the block to prevent unused local variable warning
        marketId;
        sender;

        return (feeAmount * snxFeeShare) / 1e18;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {
        return interfaceId == type(IFeeCollector).interfaceId || interfaceId == this.supportsInterface.selector;
    }

    function addressToBytes32(address _x) private pure returns (bytes32) {
        return bytes32(uint256(uint160(_x)));
    }
}
