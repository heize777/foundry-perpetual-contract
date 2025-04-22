// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OracleLib} from "./libraries/OracleLib.sol";
import {MathLib} from "./libraries/MathLib.sol";

contract Perpetual is Ownable, ReentrancyGuard {
    using OracleLib for AggregatorV3Interface;

    IERC20 public usdc;
    AggregatorV3Interface public immutable priceFeed;

    uint256 public constant PRECISION = 1e18;
    uint256 public constant INITIAL_MARGIN_RATIO = 1000; // 10%
    uint256 public constant MAINTENANCE_MARGIN_RATIO = 500; // 5%
    uint256 public constant LEVERAGE_MAX = 10 * PRECISION; // 最大杠杆倍数
    uint256 public constant MAX_FUNDING_RATE = 3 * 1e16; // 最大资金费率
    uint256 public constant TWAP_INTERVAL = 10 minutes; // TWAP窗口

    struct Trade {
        uint256 timestamp;
        uint256 price;
    }

    Trade[] public tradeHistory; // 交易记录

    struct Position {
        int256 size; // 仓位大小
        uint256 margin; // usdc抵押数量
        uint256 entryPrice; // 开仓价格
    }

    mapping(address => Position) Positions; // 用户仓位信息
    mapping(address => uint256) lastFunding; // 用户上次资金费率计算时间

    // events
    event OpenPosition(address indexed user, bool isLong, uint256 margin, uint256 leverage);
    event ClosePosition(address indexed user, int256 pnl, uint256 payout);
    event Liquidate(address indexed user, address liquidator, uint256 reward);
    event FundingSettled(address indexed user, int256 funding);

    //errors
    error Perpetual__NoTrade();
    error Perpetual__InvalidPrice();
    error Perpetual__UnderMargin();
    error Perpetual__MoreThanZero();
    error Perpetual__InvalidLeverage();
    error Perpetual__IMRFail();
    error Perpetual__TransferFail();
    error Perpetual__UnopenedPosition();
    error Perpetual__PositionIsHealthy();

    constructor(address token, address _priceFeed) Ownable(msg.sender) {
        usdc = IERC20(token);
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function recordTrade(uint256 price) internal {
        tradeHistory.push(Trade({timestamp: block.timestamp, price: price}));
    }

    function getPerpPrice() public view returns (uint256) {
        uint256 cutoff = block.timestamp - TWAP_INTERVAL;
        uint256 totalWeightedPrice = 0;
        uint256 totalTime = 0;
        uint256 len = tradeHistory.length;

        if (len == 0) {
            revert Perpetual__NoTrade();
        }

        for (uint256 i = len - 1; i >= 1; i--) {
            Trade memory curr = tradeHistory[i];
            Trade memory prev = tradeHistory[i - 1];

            if (curr.timestamp <= cutoff) {
                uint256 duration = tradeHistory[i + 1 > len - 1 ? len - 1 : i + 1].timestamp - cutoff;
                totalWeightedPrice += curr.price * duration;
                totalTime += duration;
                break;
            }

            uint256 duration = curr.timestamp - prev.timestamp;
            totalWeightedPrice += curr.price * duration;
            totalTime += duration;

            if (i == 1) break;
        }

        if (totalTime == 0) {
            return tradeHistory[len - 1].price;
        }

        return totalWeightedPrice / totalTime;
    }

    function getIndexPrice() public view returns (uint256) {
        (, int256 price,,,) = priceFeed.stalePriceCheck();
        if (price <= 0) {
            revert Perpetual__InvalidPrice();
        }
        return uint256(price) * PRECISION;
    }

    // =============== 资金费率模块 ===============

    function calculateFundingRate() public view returns (int256) {
        int256 perp = int256(getPerpPrice());
        int256 index = int256(getIndexPrice());

        int256 rate = ((perp - index) * 1e18) / index;

        if (rate > int256(MAX_FUNDING_RATE)) return int256(MAX_FUNDING_RATE);
        if (rate < -int256(MAX_FUNDING_RATE)) return -int256(MAX_FUNDING_RATE);
        return rate;
    }

    function settleFunding(address user) public {
        Position storage pos = Positions[user];
        if (pos.size == 0) {
            lastFunding[user] = block.timestamp;
            return;
        }

        uint256 t0 = lastFunding[user] == 0 ? block.timestamp : lastFunding[user];
        uint256 dt = block.timestamp - t0;
        if (dt == 0) return;

        int256 rate = calculateFundingRate();
        int256 funding = (pos.size * rate * int256(dt)) / int256(3600) / int256(PRECISION);

        if (funding > 0) {
            if (pos.margin < uint256(funding)) {
                revert Perpetual__UnderMargin();
            }
            pos.margin -= uint256(funding);
        } else {
            pos.margin += uint256(-funding);
        }

        lastFunding[user] = block.timestamp;
        emit FundingSettled(user, funding);
    }

    // =============== 交易模块 ===============
    function openPosition(bool isLong, uint256 marginAmount, uint256 leverage) external nonReentrant {
        if (marginAmount == 0) {
            revert Perpetual__MoreThanZero();
        }
        if (leverage > LEVERAGE_MAX) {
            revert Perpetual__InvalidLeverage();
        }

        settleFunding(msg.sender);

        uint256 price = getPerpPrice();
        uint256 notional = marginAmount * leverage / PRECISION;
        int256 size = int256(notional * PRECISION / price);
        if (!isLong) size = -size;

        Position storage pos = Positions[msg.sender];
        uint256 newNotional = uint256(MathLib.abs(pos.size + size)) * price / PRECISION;
        uint256 newMargin = pos.margin + marginAmount;
        if (newMargin * 10000 < newNotional * INITIAL_MARGIN_RATIO) {
            revert Perpetual__IMRFail();
        }

        pos.size += size;
        pos.margin = newMargin;
        pos.entryPrice = price;

        bool success = usdc.transferFrom(msg.sender, address(this), marginAmount);
        if (!success) {
            revert Perpetual__TransferFail();
        }
        emit OpenPosition(msg.sender, isLong, marginAmount, leverage);
    }

    function closePosition() external nonReentrant {
        settleFunding(msg.sender);
        Position storage pos = Positions[msg.sender];
        if (pos.size == 0) {
            revert Perpetual__UnopenedPosition();
        }

        uint256 price = getPerpPrice();
        int256 pnl = (int256(price) - int256(pos.entryPrice)) * int256(pos.size) / int256(PRECISION);
        if (pnl < -int256(pos.margin)) {
            revert Perpetual__UnderMargin();
        }
        uint256 payout = pnl >= 0 ? uint256(pnl) + pos.margin : pos.margin - uint256(-pnl);

        bool success = usdc.transfer(msg.sender, payout);
        if (!success) {
            revert Perpetual__TransferFail();
        }

        delete Positions[msg.sender];
        delete lastFunding[msg.sender];

        emit ClosePosition(msg.sender, pnl, payout);
    }

    function liquidate(address user) external nonReentrant {
        settleFunding(user);

        Position storage pos = Positions[user];
        if (pos.size == 0) {
            revert Perpetual__UnopenedPosition();
        }

        uint256 price = getPerpPrice();
        int256 pnl = (int256(price) - int256(pos.entryPrice)) * int256(pos.size) / int256(PRECISION);
        int256 equity = int256(pos.margin) + pnl;

        uint256 notional = uint256(MathLib.abs(pos.size) * int256(price)) / PRECISION;
        uint256 mmr = notional * MAINTENANCE_MARGIN_RATIO / 10000;

        if (equity >= int256(mmr) && equity >= 0) {
            revert Perpetual__PositionIsHealthy();
        }

        uint256 marginRemaining = pos.margin;
        uint256 reward = marginRemaining / 100;
        if (reward > marginRemaining) {
            reward = marginRemaining;
        }

        if (reward > 0) {
            bool success = usdc.transfer(msg.sender, reward);
            if (!success) {
                revert Perpetual__TransferFail();
            }
            marginRemaining -= reward;
        }

        delete Positions[user];
        delete lastFunding[user];

        emit Liquidate(user, msg.sender, reward);
    }
}
