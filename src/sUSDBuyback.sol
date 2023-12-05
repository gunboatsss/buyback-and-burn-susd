// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "solady/auth/Ownable.sol";
import {IERC20Metadata as ERC20} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

contract sUSDBuyback is Ownable {
    ERC20 public immutable sUSD;
    ERC20 public immutable USDC;
    address public constant FEE_ADDRESS = 0xfeEFEEfeefEeFeefEEFEEfEeFeefEEFeeFEEFEeF;
    uint256 private constant UNIT_DIFFERENCE = 1e12; // 1e18/1e6 from USDC

    event Buyback(uint256 _sUSDAmount, uint256 _USDCAmount);

    constructor(address _sUSD, address _USDC) {
        sUSD = ERC20(_sUSD);
        USDC = ERC20(_USDC);
        require(sUSD.decimals() == 18, "invalid decimals");
        require(USDC.decimals() == 6, "invalid decimals");
        _initializeOwner(msg.sender);
    }

    function exchange(uint256 _USDCAmountOut) external {
        uint256 _sUSDAmountIn = _USDCAmountOut * UNIT_DIFFERENCE;
        require(sUSD.allowance(msg.sender, address(this)) >= _sUSDAmountIn, "not approved");
        require(sUSD.balanceOf(msg.sender) >= _sUSDAmountIn, "not enough sUSD");
        require(USDC.balanceOf(address(this)) >= _USDCAmountOut, "not enough USDC");
        sUSD.transferFrom(msg.sender, FEE_ADDRESS, _sUSDAmountIn);
        USDC.transfer(msg.sender, _USDCAmountOut);
        emit Buyback(_sUSDAmountIn, _USDCAmountOut);
    }

    function recoverERC20(address _token) external onlyOwner {
        require(_token != address(USDC), "not usdc");
        ERC20 token = ERC20(_token);
        token.transfer(owner(), token.balanceOf(address(this)));
    }
}
