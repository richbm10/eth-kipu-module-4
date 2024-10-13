// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {StakingContract} from "../src/StakingContract.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract StakingContractTest is Test {
    StakingContract public stakingContract;
    ERC20Mock public stakingToken;
    address public owner;
    address public user1;
    address public user2;

    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant REWARD_RATE = 500; // 5% annual rate

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        stakingToken = new ERC20Mock();
        stakingContract = new StakingContract();
        stakingContract.initialize(address(stakingToken), REWARD_RATE, owner);

        stakingToken.mint(user1, INITIAL_BALANCE);
        stakingToken.mint(user2, INITIAL_BALANCE);
        stakingToken.mint(address(stakingContract), INITIAL_BALANCE * 10); // For rewards
    }

    function test_Initialize() public view {
        assertEq(
            address(stakingContract.stakingToken()),
            address(stakingToken)
        );
        assertEq(stakingContract.rewardRate(), REWARD_RATE);
        assertEq(stakingContract.owner(), owner);
    }

    function test_Stake() public {
        uint256 stakeAmount = 100 ether;
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount);
        vm.stopPrank();

        (uint256 amount, , ) = stakingContract.stakes(user1);
        assertEq(amount, stakeAmount);
    }

    function test_Withdraw() public {
        uint256 stakeAmount = 100 ether;
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount);

        skip(30 days);

        stakingContract.withdraw(stakeAmount);
        vm.stopPrank();

        (uint256 amount, , ) = stakingContract.stakes(user1);
        assertEq(amount, 0);
        assertEq(stakingToken.balanceOf(user1), INITIAL_BALANCE);
    }

    function test_ClaimReward() public {
        uint256 stakeAmount = 100 ether;
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount);

        skip(365 days);

        uint256 expectedReward = (stakeAmount * REWARD_RATE) /
            stakingContract.BASIS_POINTS();
        uint256 initialBalance = stakingToken.balanceOf(user1);

        stakingContract.claimReward();
        vm.stopPrank();

        assertApproxEqAbs(
            stakingToken.balanceOf(user1) - initialBalance,
            expectedReward,
            1e15
        );
    }

    function test_Pause() public {
        stakingContract.pause();
        assertTrue(stakingContract.paused());

        vm.expectRevert();
        vm.prank(user1);
        stakingContract.stake(100 ether);
    }

    function test_Unpause() public {
        stakingContract.pause();
        stakingContract.unpause();
        assertFalse(stakingContract.paused());

        uint256 stakeAmount = 100 ether;
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount);
        vm.stopPrank();

        (uint256 amount, , ) = stakingContract.stakes(user1);
        assertEq(amount, stakeAmount);
    }

    function testFuzz_Stake(uint256 amount) public {
        vm.assume(amount > 0 && amount <= INITIAL_BALANCE);

        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), amount);
        stakingContract.stake(amount);
        vm.stopPrank();

        (uint256 userAmount, , ) = stakingContract.stakes(user1);
        assertEq(userAmount, amount);
    }

    function testFuzz_WithdrawPartial(
        uint256 stakeAmount,
        uint256 withdrawAmount
    ) public {
        vm.assume(stakeAmount > 0 && stakeAmount <= INITIAL_BALANCE);
        vm.assume(withdrawAmount > 0 && withdrawAmount <= stakeAmount);

        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), stakeAmount);
        stakingContract.stake(stakeAmount);

        skip(30 days);

        stakingContract.withdraw(withdrawAmount);
        vm.stopPrank();

        (uint256 amount, , ) = stakingContract.stakes(user1);
        assertEq(amount, stakeAmount - withdrawAmount);
    }
}
