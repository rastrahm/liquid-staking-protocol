// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {StETH} from "../src/StETH.sol";
import {FeeDistributor} from "../src/FeeDistributor.sol";
import {AccountingOracle} from "../src/AccountingOracle.sol";
import {LiquidStakingErrors} from "../src/errors/LiquidStakingErrors.sol";
import {StETHHarness} from "./helpers/Harnesses.sol";

/// @title OracleReportTest
/// @notice Auth, interval, positive/negative rebase and protocol fee minting.
contract OracleReportTest is Test {
    StETH internal steth;
    FeeDistributor internal fees;
    AccountingOracle internal oracle;

    address internal owner = makeAddr("owner");
    address internal reporter = makeAddr("reporter");
    address internal stranger = makeAddr("stranger");
    address internal treasury = makeAddr("treasury");
    address internal operators = makeAddr("operators");
    address internal alice = makeAddr("alice");

    uint256 internal constant REPORT_INTERVAL = 1 hours;
    uint16 internal constant FEE_BPS = 1000; // 10%
    uint16 internal constant TREASURY_SHARE_BPS = 5000; // 50% of fee shares

    function setUp() public {
        vm.deal(alice, 1_000 ether);
        vm.deal(reporter, 1 ether);

        steth = new StETH(owner);
        fees = new FeeDistributor(FEE_BPS, treasury, operators, TREASURY_SHARE_BPS);

        vm.startPrank(owner);
        steth.setFeeDistributor(address(fees));
        oracle = new AccountingOracle(address(steth), REPORT_INTERVAL, reporter, owner);
        steth.setOracle(address(oracle));
        vm.stopPrank();
    }

    function test_feeDistributor_revertsAboveCap() public {
        vm.expectRevert(LiquidStakingErrors.FeeCapExceeded.selector);
        new FeeDistributor(1001, treasury, operators, TREASURY_SHARE_BPS);
    }

    function test_unauthorizedOracle_directCall_reverts() public {
        vm.prank(stranger);
        vm.expectRevert(LiquidStakingErrors.UnauthorizedOracle.selector);
        steth.handleOracleReport(0, 0);
    }

    function test_unauthorizedOracle_submitReport_reverts() public {
        vm.prank(stranger);
        vm.expectRevert(LiquidStakingErrors.UnauthorizedOracle.selector);
        oracle.submitReport(10 ether, 0);
    }

    function test_reportTooEarly_reverts() public {
        vm.prank(alice);
        steth.submit{value: 10 ether}();

        vm.prank(reporter);
        oracle.submitReport(0, 0);

        vm.prank(reporter);
        vm.expectRevert(LiquidStakingErrors.ReportTooEarly.selector);
        oracle.submitReport(1 ether, 0);
    }

    function test_positiveRebase_increasesHolderBalance_andMintsFees() public {
        vm.prank(alice);
        steth.submit{value: 10 ether}();

        // Reward: CL balance rises by 5 ETH while buffer stays 10 → pooled 15.
        vm.prank(reporter);
        oracle.submitReport(5 ether, 0);

        uint256 aliceBal = steth.balanceOf(alice);
        assertGt(aliceBal, 10 ether);
        assertLt(aliceBal, 15 ether);

        uint256 feeValue = steth.balanceOf(treasury) + steth.balanceOf(operators);
        assertApproxEqAbs(feeValue, 0.5 ether, 2);

        assertEq(steth.getClBalance(), 5 ether);
        assertEq(steth.getTotalPooledEther(), 15 ether);
        assertGt(steth.sharesOf(treasury) + steth.sharesOf(operators), 0);
    }

    function test_positiveRebase_withElRewards() public {
        vm.prank(alice);
        steth.submit{value: 10 ether}();

        vm.deal(address(steth), address(steth).balance + 2 ether);

        vm.prank(reporter);
        oracle.submitReport(0, 2 ether);

        assertEq(steth.getBufferedEther(), 12 ether);
        assertEq(steth.getTotalPooledEther(), 12 ether);

        uint256 feeValue = steth.balanceOf(treasury) + steth.balanceOf(operators);
        assertApproxEqAbs(feeValue, 0.2 ether, 1);
        assertGt(steth.balanceOf(alice), 10 ether);
    }

    function test_elRewards_withoutEth_revertsInvalidReport() public {
        vm.prank(alice);
        steth.submit{value: 10 ether}();

        vm.prank(reporter);
        vm.expectRevert(LiquidStakingErrors.InvalidReport.selector);
        oracle.submitReport(0, 1 ether);
    }

    function test_negativeRebase_decreasesHolderBalance() public {
        vm.prank(alice);
        steth.submit{value: 10 ether}();

        vm.prank(reporter);
        oracle.submitReport(10 ether, 0); // pooled = 20

        vm.warp(block.timestamp + REPORT_INTERVAL + 1);

        uint256 balBefore = steth.balanceOf(alice);
        assertEq(steth.getTotalPooledEther(), 20 ether);

        vm.prank(reporter);
        oracle.submitReport(4 ether, 0); // -6 ETH

        assertEq(steth.getTotalPooledEther(), 14 ether);
        assertLt(steth.balanceOf(alice), balBefore);
        assertEq(steth.sharesOf(alice), 10 ether);
    }

    function test_negativeRebaseBlocked_whenPooledWouldBeZero() public {
        StETHHarness harness = new StETHHarness();
        address harOwner = harness.owner();

        FeeDistributor localFees = new FeeDistributor(FEE_BPS, treasury, operators, TREASURY_SHARE_BPS);
        AccountingOracle localOracle =
            new AccountingOracle(address(harness), REPORT_INTERVAL, reporter, harOwner);

        vm.startPrank(harOwner);
        harness.setFeeDistributor(address(localFees));
        harness.setOracle(address(localOracle));
        vm.stopPrank();

        vm.deal(alice, 10 ether);
        vm.prank(alice);
        harness.submit{value: 10 ether}();
        harness.moveBufferToCl(); // buffer=0, cl=10, shares=10

        vm.prank(reporter);
        vm.expectRevert(LiquidStakingErrors.NegativeRebaseBlocked.selector);
        localOracle.submitReport(0, 0);
    }

    function test_feeSplit_fiftyFifty() public {
        vm.prank(alice);
        steth.submit{value: 100 ether}();

        vm.prank(reporter);
        oracle.submitReport(100 ether, 0); // reward 100 ETH, fee 10 ETH

        uint256 tBal = steth.balanceOf(treasury);
        uint256 oBal = steth.balanceOf(operators);
        assertApproxEqAbs(tBal, oBal, 2);
        assertApproxEqAbs(tBal + oBal, 10 ether, 2);
    }

    function test_holdersCanTransfer_afterNegativeRebase() public {
        vm.prank(alice);
        steth.submit{value: 10 ether}();

        vm.prank(reporter);
        oracle.submitReport(10 ether, 0);
        vm.warp(block.timestamp + REPORT_INTERVAL + 1);
        vm.prank(reporter);
        oracle.submitReport(2 ether, 0);

        address bob = makeAddr("bob");
        uint256 sharesHalf = steth.sharesOf(alice) / 2;
        vm.prank(alice);
        steth.transferShares(bob, sharesHalf);
        assertEq(steth.sharesOf(bob), sharesHalf);
    }

    function test_addRemoveMember() public {
        address other = makeAddr("other");
        vm.prank(owner);
        oracle.addMember(other);
        assertTrue(oracle.members(other));

        vm.prank(owner);
        oracle.removeMember(other);
        assertFalse(oracle.members(other));
    }

    function test_removeLastMember_reverts() public {
        vm.prank(owner);
        vm.expectRevert(LiquidStakingErrors.InvalidReport.selector);
        oracle.removeMember(reporter);
    }
}
