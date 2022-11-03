// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/UniERC20.sol";
import "./Mooniswap.sol";
import "./interfaces/IMooniswap.sol";

contract MooniFactory is Ownable {
    using UniERC20 for IERC20;

    event Deployed(
        address indexed mooniswap,
        address indexed token1,
        address indexed token2
    );

    uint256 public constant MAX_FEE = 0.003e18; // 0.3%

    uint256 public fee;
    address[] public allPools;
    mapping(address => bool) public isPool;
    mapping(IERC20 => mapping(IERC20 => address)) public pools;

    function getAllPools() external view returns(address[] memory) {
        return allPools;
    }

    function setFee(uint256 newFee) external onlyOwner {
        require(newFee <= MAX_FEE, "Factory: fee should be <= 0.3%");
        fee = newFee;
    }
    // function createPair(address tokenA, address tokenB)
    //     external
    //     returns (address pair)
    // {

    //     bytes memory bytecode = type(PegasysPair).creationCode;
    //     bytes32 salt = keccak256(abi.encodePacked(token0, token1));
    //     assembly {
    //         pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
    //     }
    //     IPegasysPair(pair).initialize(token0, token1);
    //     getPair[token0][token1] = pair;
    //     getPair[token1][token0] = pair; // populate mapping in the reverse direction
    //     allPairs.push(pair);
       
    // }
    function deploy(IERC20 tokenA, IERC20 tokenB) public  returns (address pair) {
        require(tokenA != tokenB, "Factory: not support same tokens");
        require(pools[tokenA][tokenB] == address(0), "Factory: pool already exists");

        (IERC20 token1, IERC20 token2) = sortTokens(tokenA, tokenB);
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = token1;
        tokens[1] = token2;

        string memory symbol1 = token1.uniSymbol();
        string memory symbol2 = token2.uniSymbol();

        bytes memory bytecode = type(Mooniswap).creationCode;
        bytes memory bytecodeWithArgs = abi.encodePacked(
            bytecode,
            abi.encode(tokens,
                string(abi.encodePacked("Mooniswap V1 (", symbol1, "-", symbol2, ")")),
                string(abi.encodePacked("MOON-V1-", symbol1, "-", symbol2))
            )
        );
        bytes32 salt = keccak256(abi.encodePacked(tokenA, tokenB));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecodeWithArgs), salt)
        }
        IMooniswap(pair).transferOwnership(owner());
        //pool.transferOwnership(owner());
        pools[token1][token2] = pair;
        pools[token2][token1] = pair;
        allPools.push(pair);
        isPool[pair] = true;

        emit Deployed(
            address(pair),
            address(token1),
            address(token2)
        );
    }

    function sortTokens(IERC20 tokenA, IERC20 tokenB) public pure returns(IERC20, IERC20) {
        if (tokenA < tokenB) {
            return (tokenA, tokenB);
        }
        return (tokenB, tokenA);
    }
}
