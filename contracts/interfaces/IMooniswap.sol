pragma solidity ^0.6.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./libraries/UniERC20.sol";
import "./libraries/Sqrt.sol";

library VirtualBalance {
    using SafeMath for uint256;

    struct Data {
        uint216 balance;
        uint40 time;
    }

    uint256 public constant DECAY_PERIOD = 5 minutes;

    function set(VirtualBalance.Data storage self, uint256 balance) internal {
        self.balance = uint216(balance);
        self.time = uint40(block.timestamp);
    }

    function update(VirtualBalance.Data storage self, uint256 realBalance) internal {
        set(self, current(self, realBalance));
    }

    function scale(VirtualBalance.Data storage self, uint256 realBalance, uint256 num, uint256 denom) internal {
        set(self, current(self, realBalance).mul(num).add(denom.sub(1)).div(denom));
    }

    function current(VirtualBalance.Data memory self, uint256 realBalance) internal view returns(uint256) {
        uint256 timePassed = Math.min(DECAY_PERIOD, block.timestamp.sub(self.time));
        uint256 timeRemain = DECAY_PERIOD.sub(timePassed);
        return uint256(self.balance).mul(timeRemain).add(
            realBalance.mul(timePassed)
        ).div(DECAY_PERIOD);
    }
}

interface IFactory {
    function fee() external view returns(uint256);
}

interface IMooniswap is ERC20{
    using Sqrt for uint256;
    using SafeMath for uint256;
    using UniERC20 for IERC20;
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



    function fee() public view returns(uint256);

    function getTokens() external view returns(IERC20[] memory);

    function decayPeriod() external pure returns(uint256);

    function getBalanceForAddition(IERC20 token) public view returns(uint256);
    function getBalanceForRemoval(IERC20 token) public view returns(uint256);

    function getReturn(IERC20 src, IERC20 dst, uint256 amount) external view returns(uint256);

    function deposit(uint256[] calldata amounts, uint256[] calldata minAmounts) external payable returns(uint256 fairSupply);

    function withdraw(uint256 amount, uint256[] memory minReturns) external;

    function swap(IERC20 src, IERC20 dst, uint256 amount, uint256 minReturn, address referral) external payable returns(uint256 result);

    function rescueFunds(IERC20 token, uint256 amount) external;

    function _getReturn(IERC20 src, IERC20 dst, uint256 amount, uint256 srcBalance, uint256 dstBalance) internal view returns(uint256);

}