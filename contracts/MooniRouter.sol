// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;


import "./libraries/UniERC20.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/MathLib.sol";

import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IMooniswap.sol";

import "./MooniFactory.sol";
import "./Mooniswap.sol";


contract MooniRouter {
    using UniERC20 for IERC20;
    address public immutable override factory;
    address public immutable override WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        IERC20 tokenA,
        IER20 tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) private returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (MooniFactory(factory).pools(tokenA, tokenB) == address(0)) {
            MooniFactory(factory).deploy(tokenA, tokenB);
        }/////maybe reserveA = TokenA.balanceOf(address(this))??
       // (uint reserveA, uint reserveB) = MathLib.getReserves(factory, tokenA, tokenB);
        address pair = MooniFactory(factory).pairFor(tokenA, tokenB);
       uint reserveA = tokenA.balenceOf(pair);
       uint reserveB = tokenB.balenceOf(pair);
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
        IERC20 tokenA,
        IERC20 tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to
    ) external override returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = MooniFactory(factory).pairFor(tokenA, tokenB);

        uint[] calldata amounts = new uint[](2);
        amounts[0] = amountA;
        amounts[1] = amountB;

        IMooniswap(pair).deposit(amounts, amounts);
        uint amount = IMooniswap.balenceOf(address(this));
        IMooniswap(pair).transfer(to, amount); ///new way

        // TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        // TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        // liquidity = IUniswapV2Pair(pair).mint(to);  UNISWAPV2 WAY
    }
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to
    ) external override payable returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );

        uint[] calldata amounts = new uint[](2);
        amounts[0] = amountA;

        address pair = MooniFactory(factory).pairFor(token, WETH);
        IMooniswap(pair).deposit{value: amountETH}(amounts, amounts);
        uint amount = IMooniswap.balenceOf(address(this));
        IMooniswap(pair).transfer(to, amount); ///new way
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH); // refund dust eth, if any
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to
 
    ) public override returns (uint amountA, uint amountB) {
        address pair = MooniFactory(factory).pairFor( tokenA, tokenB);

        uint[] memory amounts = new uint[](2);
        amounts[0] = amountAMin;
        amounts[1] = amountBMin;  
        IMooniswap(pair).withdraw(liquidity, amounts);

        uint amountWA = IERC20(tokenA).balenceOf(address(this));
        uint amountWB = IERC20(tokenB).balenceOf(address(this));

        TransferHelper.safeTransfer(tokenA, to, amountWA);
        TransferHelper.safeTransfer(tokenB, to, amountWB);

        (address token0,) = MathLib.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "INSUFFICIENT_B_AMOUNT");
    }
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to
    ) public override returns (uint amountToken, uint amountETH) {
        address pair = MooniFactory(factory).pairFor( WETH, token);
        uint[] memory amounts = new uint[](2);
        amounts[0] = amountAMin;
        amounts[1] = amountBMin;  
        IMooniswap(pair).withdraw(liquidity, amounts);
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );

        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
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
    ) external override returns (uint amountA, uint amountB) {
        address pair = MooniFactory(factory).pairFor( tokenA, tokenB);
        uint value = approveMax ? uint(-1) : liquidity;
         IMooniswap(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
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

              IMooniswap(MooniFactory(factory).pairFor( input, output)).swap(input, output, amount0Out, amount1Out, referral);
               // amount0Out, amount1Out, to, new bytes(0));
        }
        if(output == WETH ) {
        IWETH(WETH).withdraw(amount1Out);
        TransferHelper.safeTransferETH(to,amount1Out);
        } else {
        TransferHelper.safeTransfer(output, _to, amount1Out);
        }
       
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        address referral
    ) external override returns (uint[] memory amounts) {
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
    ) external override  returns (uint[] memory amounts) {
        amounts = MathLib.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax,"EXCESSIVE_INPUT_AMOUNT");
      TransferHelper.safeTransfer(path[0], address(this), amounts[0]);
       swap(amounts, path, to,referral);
    }
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to)
        external
        override
        payable
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, "INVALID_PATH");
        amounts = MathLib.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH(WETH).deposit{value: amounts[0]}();
        TransferHelper.safeTransfer(path[0], address(this), amounts[0]);
        _swap(amounts, path, to);
    }
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to)
        external
        override
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, "INVALID_PATH");
        amounts = MathLib.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransfer(path[0], address(this), amounts[0]);
        _swap(amounts, path, address(this));
       
    }
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to)
        external
        override
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, "INVALID_PATH");
        amounts = MathLib.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransfer(path[0], address(this), amounts[0]);
        _swap(amounts, path, address(this));

    }
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to)
        external
        override
        payable
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, "INVALID_PATH");
        amounts = MathLib.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, "EXCESSIVE_INPUT_AMOUNT");
        IWETH(WETH).deposit{value: amounts[0]}();
        TransferHelper.safeTransfer(path[0], address(this), amounts[0]);
        _swap(amounts, path, to);
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]); // refund dust eth, if any
    }

    function quote(uint amountA, uint reserveA, uint reserveB) public pure override returns (uint amountB) {
        return MathLib.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure override returns (uint amountOut) {
        return MathLib.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) public pure override returns (uint amountIn) {
        return MathLib.getAmountOut(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path) public view override returns (uint[] memory amounts) {
        return MathLib.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path) public view override returns (uint[] memory amounts) {
        return MathLib.getAmountsIn(factory, amountOut, path);
    }
}

    


