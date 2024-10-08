// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "solady/auth/Ownable.sol";
import {IERC20Metadata as ERC20} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract sUSDBuyback is Ownable {
    ERC20 public immutable sUSD = ERC20(0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9);
    ERC20 public immutable USDC = ERC20(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85);
    address public constant FEE_ADDRESS = 0xfeEFEEfeefEeFeefEEFEEfEeFeefEEFeeFEEFEeF;
    uint256 private constant UNIT_DIFFERENCE = 1e12; // 1e18/1e6 from USDC

    event Buyback(uint256 _sUSDAmount, uint256 _USDCAmount);

    constructor(address _owner) {
        _initializeOwner(_owner);
    }

    /// @notice Exchange sUSD into USDC function
    /// @dev Using USDC amount, there will be no dust as USDC decimals (6) is scales into sUSD amount (18)
    /// @param _USDCAmountOut Amount of USDC to received
    function exchange(uint256 _USDCAmountOut) external {
        uint256 _sUSDAmountIn = _USDCAmountOut * UNIT_DIFFERENCE;
        require(sUSD.balanceOf(msg.sender) >= _sUSDAmountIn, "not enough sUSD");
        require(USDC.balanceOf(address(this)) >= _USDCAmountOut, "not enough USDC");
        sUSD.transferFrom(msg.sender, FEE_ADDRESS, _sUSDAmountIn);
        USDC.transfer(msg.sender, _USDCAmountOut);
        emit Buyback(_sUSDAmountIn, _USDCAmountOut);
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param _token a valid ERC-20 token address
    function recoverERC20(address _token) external onlyOwner {
        require(_token != address(USDC), "not usdc");
        SafeTransferLib.safeTransferAll(_token, owner());
    }
}
