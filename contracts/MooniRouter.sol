// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;


import "./libraries/UniERC20.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/MathLib.sol";

//import "./interfaces/IERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import "./interfaces/IMooniswap.sol";

import "./MooniFactory.sol";
import "./Mooniswap.sol";


contract MooniRouter {
    using UniERC20 for IERC20;
    address public immutable  factory;
    address public immutable  WETH;


    constructor(address _factory, address _WETH) public payable{
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {}

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) private returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (MooniFactory(factory).pools(IERC20(tokenA), IERC20(tokenB)) == address(0)) {
            MooniFactory(factory).deploy(IERC20(tokenA), IERC20(tokenB));
        }
       // (uint reserveA, uint reserveB) = MathLib.getReserves(factory, tokenA, tokenB);
        address pair = MooniFactory(factory).pairFor(address(tokenA), address(tokenB));
       uint reserveA = IERC20(tokenA).balanceOf(pair);
       uint reserveB = IERC20(tokenB).balanceOf(pair);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = MathLib.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = MathLib.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to
    ) public payable returns (uint liquidity) {
        if (MooniFactory(factory).pools(IERC20(tokenA), IERC20(tokenB)) == address(0)) {
            MooniFactory(factory).deploy(IERC20(tokenA), IERC20(tokenB));
        }
        //(amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = MooniFactory(factory).pairFor(tokenA, tokenB);
 
        IERC20(tokenA).transferFrom(msg.sender,address(this), amountADesired);
        IERC20(tokenB).transferFrom(msg.sender,address(this), amountBDesired);

        IERC20(tokenA).approve(pair, amountADesired);
        IERC20(tokenB).approve(pair, amountBDesired);



        uint[] memory amounts = new uint[](2);
        amounts[0] = amountADesired;
        amounts[1] = amountBDesired;

        uint[] memory amountsMin = new uint[](2);
        amountsMin[0] = amountAMin;
        amountsMin[1] = amountBMin;

        uint liquidity = IMooniswap(pair).deposit(amounts, amountsMin);
        uint amount = IMooniswap(pair).balanceOf(address(this));
       // TransferHelper.safeTransfer(pair, to, amount);
       IMooniswap(pair).transfer(to, amount); ///new way

        return liquidity;

 
    }


    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to
    ) external  payable  returns (uint liquidity) {

        IWETH(WETH).deposit{value: msg.value}();
        uint amountADesired = IWETH(WETH).balanceOf(address(this));
        IWETH(WETH).transfer(msg.sender, amountADesired);

        uint liquidity = addLiquidity(
        WETH,
        token,
       amountADesired,
        amountTokenDesired,
       amountETHMin,
       amountTokenMin,
         to
    );

        return liquidity;

    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to
    ) public  returns (uint amountA, uint amountB) {
        address pair = MooniFactory(factory).pairFor( tokenA, tokenB);


        IMooniswap(pair).transferFrom(msg.sender,address(this), liquidity);
        uint[] memory amounts = new uint[](2);
        amounts[0] = amountAMin;
        amounts[1] = amountBMin;  
        IMooniswap(pair).withdraw(liquidity, amounts);

        uint amountWA = IERC20(tokenA).balanceOf(address(this));
        uint amountWB = IERC20(tokenB).balanceOf(address(this));

        TransferHelper.safeTransfer(tokenA, to, amountWA);
        TransferHelper.safeTransfer(tokenB, to, amountWB);

        (address token0,) = MathLib.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amounts[0], amounts[1]) : (amounts[1], amounts[0]);
        require(amountA >= amountAMin, "INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "INSUFFICIENT_B_AMOUNT");
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to
    ) public  returns (uint amountToken, uint amountETH) {
        address pair = MooniFactory(factory).pairFor( WETH, token);


        IMooniswap(pair).transferFrom(msg.sender,address(this), liquidity);
        uint[] memory amounts = new uint[](2);
        amounts[0] = amountETHMin;
        amounts[1] = amountTokenMin;  
        IMooniswap(pair).withdraw(liquidity, amounts);

        uint amountETH = IWETH(WETH).balanceOf(address(this));
        uint amountToken = IERC20(token).balanceOf(address(this));
        IWETH(WETH).withdraw(amountETH);

        TransferHelper.safeTransferETH(to, amountETH);
        TransferHelper.safeTransfer(token, to, amountToken);

        (address token0,) = MathLib.sortTokens(WETH, token);
        (amountETH, amountToken) = WETH == token0 ? (amounts[0], amounts[1]) : (amounts[1], amounts[0]);
        require(amountToken >= amountTokenMin, "INSUFFICIENT_A_AMOUNT");
        require(amountETH >= amountETHMin, "INSUFFICIENT_B_AMOUNT");
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external  returns (uint amountA, uint amountB) {
        address pair = MooniFactory(factory).pairFor( tokenA, tokenB);
        uint value = approveMax ? uint(-1) : liquidity;
         IMooniswap(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to);
    }


    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to,  address referral) private {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = MathLib.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
          
           
            address to = i < path.length - 2 ? MooniFactory(factory).pairFor( output, path[i + 2]) : _to;
            address pair = MooniFactory(factory).pairFor( input, output);
            IMooniswap(pair).swap(IERC20(input), IERC20(output), amount0Out, amount1Out, referral);
        }
        uint lastIndex = path.length - 1;
        address lastPath = path[lastIndex];
        
        if(lastPath == WETH ) {
            uint amountOutLastPath = IWETH(WETH).balanceOf(address(this));
            IWETH(WETH).withdraw(amountOutLastPath);
            TransferHelper.safeTransferETH(_to,amountOutLastPath);
        } else {
            uint amountOutLastPath = IERC20(lastPath).balanceOf(address(this));
            TransferHelper.safeTransfer(lastPath, _to, amountOutLastPath);
        }
       
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        address referral
    ) external  returns (uint[] memory amounts) {
        amounts = MathLib.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "Router: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransfer(path[0], address(this), amounts[0]);
        _swap(amounts, path, to,referral);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        address referral
    ) external   returns (uint[] memory amounts) {
        amounts = MathLib.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax,"EXCESSIVE_INPUT_AMOUNT");
      TransferHelper.safeTransfer(path[0], address(this), amounts[0]);
       _swap(amounts, path, to,referral);
    }
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, address referral)
        external
        
        payable
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, "INVALID_PATH");
        amounts = MathLib.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH(WETH).deposit{value: amounts[0]}();
        TransferHelper.safeTransfer(path[0], address(this), amounts[0]);
        _swap(amounts, path, to, referral);
    }
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, address referral)
        external
        
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, "INVALID_PATH");
        amounts = MathLib.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransfer(path[0], address(this), amounts[0]);
        _swap(amounts, path, address(this), referral);
       
    }
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, address referral)
        external
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, "INVALID_PATH");
        amounts = MathLib.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransfer(path[0], address(this), amounts[0]);
        _swap(amounts, path, address(this), referral);

    }
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, address referral)
        external
    
        payable
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, "INVALID_PATH");
        amounts = MathLib.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, "EXCESSIVE_INPUT_AMOUNT");
        IWETH(WETH).deposit{value: amounts[0]}();
        TransferHelper.safeTransfer(path[0], address(this), amounts[0]);
        _swap(amounts, path, to, referral);
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]); // refund dust eth, if any
    }

    function quote(uint amountA, uint reserveA, uint reserveB) public pure  returns (uint amountB) {
        return MathLib.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure  returns (uint amountOut) {
        return MathLib.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) public pure  returns (uint amountIn) {
        return MathLib.getAmountOut(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path) public view  returns (uint[] memory amounts) {
        return MathLib.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path) public view  returns (uint[] memory amounts) {
        return MathLib.getAmountsIn(factory, amountOut, path);
    }
}

    


