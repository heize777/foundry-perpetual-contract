// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Perpetual} from "../../src/Perpetual.sol";
import {OracleLib} from "../../src/libraries/OracleLib.sol";
import {MathLib} from "../../src/libraries/MathLib.sol";
import {Test} from "forge-std/Test.sol";
import {DeployPerpetual} from "../../script/DeployPerpetual.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract PerpetualTest is Test {
    Perpetual public perpetual;
    HelperConfig public config;

    address public user = address(1);
    address usdc;
    address priceFeed;

    function setUp() public {
        DeployPerpetual deployer = new DeployPerpetual();
        (perpetual, config) = deployer.run();
        (usdc, priceFeed,) = config.activeNetworkConfig();
        ERC20Mock(usdc).mint(user, 1000000);
        ERC20Mock(usdc).approve(address(perpetual), type(uint256).max);
    }

    function test_OpenPosition_ZeroMargin_ShouldRevert() public {
        vm.expectRevert(Perpetual.Perpetual__MoreThanZero.selector);
        perpetual.openPosition(true, 0, 1000);
    }

    function test_OpenPosition_ExceedsMaxLeverage_ShouldRevert() public {
        vm.expectRevert(Perpetual.Perpetual__InvalidLeverage.selector);
        perpetual.openPosition(true, 1000, 11 * 1e18);
    }

    function test_OpenPosition_InsufficientMargin_ShouldRevert() public {
        priceFeed.setLatestAnswer(1000000000000000000);
        vm.expectRevert(Perpetual.Perpetual__IMRFail.selector);
        perpetual.openPosition(true, 1000, 1000);
    }

    function test_OpenPosition_SuccessfulOpening() public {
        priceFeed.setLatestAnswer(1000000000000000000);
        perpetual.openPosition(true, 1000, 1000);
        Perpetual.Position memory pos = perpetual.Positions(user);
        assertEq(pos.margin, 1000);
    }

    function test_ClosePosition_UnopenedPosition_ShouldRevert() public {
        vm.expectRevert(Perpetual.Perpetual__UnopenedPosition.selector);
        perpetual.closePosition();
    }

    function test_ClosePosition_SuccessfulClosing() public {
        priceFeed.setLatestAnswer(1000000000000000000);
        perpetual.openPosition(true, 1000, 1000);
        perpetual.closePosition();
        Perpetual.Position memory pos = perpetual.Positions(user);
        assertEq(pos.margin, 0);
    }

    function test_Liquidate_UnopenedPosition_ShouldRevert() public {
        vm.expectRevert(Perpetual.Perpetual__UnopenedPosition.selector);
        perpetual.liquidate(user);
    }

    function test_Liquidate_SuccessfulLiquidation() public {
        priceFeed.setLatestAnswer(1000000000000000000);
        perpetual.openPosition(true, 1000, 1000);
        priceFeed.setLatestAnswer(1500000000000000000);
        perpetual.liquidate(user);
        Perpetual.Position memory pos = perpetual.Positions(user);
        assertEq(pos.margin, 0);
    }
}
