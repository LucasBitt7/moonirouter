pragma solidity ^0.6.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../libraries/UniERC20.sol";
import "../libraries/Sqrt.sol";
import "../Mooniswap.sol";

abstract contract IMooniswap is ERC20, Ownable{

    using VirtualBalance for VirtualBalance.Data;

    struct Balances {
        uint256 src;
        uint256 dst;
    }

    struct SwapVolumes {
        uint128 confirmed;
        uint128 result;
    }

    event Deposited(
        address indexed account,
        uint256 amount
    );

    event Withdrawn(
        address indexed account,
        uint256 amount
    );

    event Swapped(
        address indexed account,
        address indexed src,
        address indexed dst,
        uint256 amount,
        uint256 result,
        uint256 srcBalance,
        uint256 dstBalance,
        uint256 totalSupply,
        address referral
    );

    uint256 public constant REFERRAL_SHARE = 20; // 1/share = 5% of LPs revenue
    uint256 public constant BASE_SUPPLY = 1000;  // Total supply on first deposit
    uint256 public constant FEE_DENOMINATOR = 1e18;

    IFactory public factory;
    IERC20[] public tokens;
    mapping(IERC20 => bool) public isToken;
    mapping(IERC20 => SwapVolumes) public volumes;
    mapping(IERC20 => VirtualBalance.Data) public virtualBalancesForAddition;
    mapping(IERC20 => VirtualBalance.Data) public virtualBalancesForRemoval;

    function initialize(IERC20[] memory assets) external virtual;

    function fee() external virtual view returns(uint256);

    function getTokens() external virtual view returns(IERC20[] memory);

    function decayPeriod() external virtual pure returns(uint256);

    function getBalanceForAddition(IERC20 token) external virtual view returns(uint256);
    function getBalanceForRemoval(IERC20 token) external view virtual returns(uint256);

    function getReturn(IERC20 src, IERC20 dst, uint256 amount) external virtual view returns(uint256);

    function deposit(uint256[] calldata amounts, uint256[] calldata minAmounts) external virtual payable returns(uint256 fairSupply);

    function withdraw(uint256 amount, uint256[] memory minReturns) external virtual;

    function swap(IERC20 src, IERC20 dst, uint256 amount, uint256 minReturn, address referral) external virtual payable returns(uint256 result);

    function rescueFunds(IERC20 token, uint256 amount) external virtual;

    function _getReturn(IERC20 src, IERC20 dst, uint256 amount, uint256 srcBalance, uint256 dstBalance) internal virtual view returns(uint256);
    function permit(address _owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external virtual;
}