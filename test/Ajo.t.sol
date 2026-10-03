// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "../lib/forge-std/src/Test.sol";
import {Ajo} from "../src/Ajo.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract AjoTest is Test {
    Ajo public ajo;
    MockUSDC public token;

    address public organizer;
    address public alice;
    address public bob;
    address public charlie;

    uint256 constant CONTRIBUTION = 100e6; // 100 mUSDC
    uint256 constant CYCLE_DURATION = 7 days;
    uint256 constant MAX_MEMBERS = 3;

    function setUp() public {
        organizer = makeAddr("organizer");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        token = new MockUSDC();

        vm.prank(organizer);
        ajo = new Ajo(
            address(token),
            CONTRIBUTION,
            CYCLE_DURATION,
            MAX_MEMBERS
        );
    }
    function testDeployment() public {
    assertEq(address(ajo.token()), address(token));
    assertEq(ajo.organizer(), organizer);
    assertEq(ajo.contributionAmount(), CONTRIBUTION);
    assertEq(ajo.cycleDuration(), CYCLE_DURATION);
    assertEq(ajo.maxMembers(), MAX_MEMBERS);

    assertEq(ajo.memberCount(), 0);
    assertEq(ajo.currentCycle(), 0);
    assertEq(ajo.started(), false);
    assertEq(ajo.closed(), false);
    } 
    function testMemberCanJoin() public {
    vm.prank(alice);
    ajo.join();

    assertEq(ajo.memberCount(), 1);

    (address memberAddress, uint256 position, , bool hasJoined) =
        ajo.members(alice);

    assertEq(memberAddress, alice);
    assertEq(position, 0);
    assertTrue(hasJoined);
    }
    function testCannotJoinTwice() public {
    vm.startPrank(alice);

    ajo.join();

    vm.expectRevert(Ajo.AlreadyJoined.selector);
    ajo.join();

    vm.stopPrank();
    }
    function testCannotExceedMaxMembers() public {
    vm.prank(alice);
    ajo.join();

    vm.prank(bob);
    ajo.join();

    vm.prank(charlie);
    ajo.join();

    address dave = makeAddr("dave");

    vm.prank(dave);
    vm.expectRevert(Ajo.MemberLimitReached.selector);
    ajo.join();
    }
    function testOrganizerCanStartPool() public {
    vm.prank(alice);
    ajo.join();

    vm.prank(bob);
    ajo.join();

    vm.prank(organizer);
    ajo.startPool();

    assertTrue(ajo.started());
    assertEq(ajo.currentCycle(), 1);
    assertEq(ajo.memberCount(), 2);
    }
    function testOnlyOrganizerCanStartPool() public {
    vm.prank(alice);
    ajo.join();

    vm.prank(bob);
    ajo.join();

    vm.prank(alice);
    vm.expectRevert(Ajo.NotOrganizer.selector);
    ajo.startPool();
    }
    function testMemberCanContribute() public {
    // Add two members
    vm.prank(alice);
    ajo.join();

    vm.prank(bob);
    ajo.join();

    // Organizer starts the pool
    vm.prank(organizer);
    ajo.startPool();

    // Give Alice enough mock USDC
    token.mint(alice, CONTRIBUTION);

    // Alice approves the Ajo contract to spend her USDC
    vm.prank(alice);
    token.approve(address(ajo), CONTRIBUTION);

    // Alice contributes
    vm.prank(alice);
    ajo.contribute();

    // Check that her contribution was recorded
    assertEq(
        token.balanceOf(address(ajo)),
        CONTRIBUTION
    );

    assertEq(
        ajo.contributionsThisCycle(),
        1
    );

    assertTrue(
        ajo.contributedInCycle(1, alice)
    );
   }
   function testCannotContributeTwice() public {
    vm.prank(alice);
    ajo.join();

    vm.prank(bob);
    ajo.join();

    vm.prank(organizer);
    ajo.startPool();

    // Give Alice USDC
    token.mint(alice, CONTRIBUTION * 2);

    // Approve Ajo contract
    vm.prank(alice);
    token.approve(address(ajo), CONTRIBUTION * 2);

    // First contribution should succeed
    vm.prank(alice);
    ajo.contribute();

    // Second contribution should fail
    vm.prank(alice);
    vm.expectRevert(Ajo.ContributionAlreadyMade.selector);
    ajo.contribute();
   }
   function testNonMemberCannotContribute() public {
    // Add two valid members
    vm.prank(alice);
    ajo.join();

    vm.prank(bob);
    ajo.join();

    // Start the pool
    vm.prank(organizer);
    ajo.startPool();

    // Give Dave some USDC
    address dave = makeAddr("dave");
    token.mint(dave, CONTRIBUTION);

    // Dave approves the Ajo contract
    vm.prank(dave);
    token.approve(address(ajo), CONTRIBUTION);

    // Dave is not a member, so this must fail
    vm.prank(dave);
    vm.expectRevert(Ajo.NotMember.selector);
    ajo.contribute();
   }
   function testPayoutAfterAllMembersContribute() public {
    // Alice and Bob join
    vm.prank(alice);
    ajo.join();

    vm.prank(bob);
    ajo.join();

    // Organizer starts the pool
    vm.prank(organizer);
    ajo.startPool();

    // Give both members enough USDC
    token.mint(alice, CONTRIBUTION);
    token.mint(bob, CONTRIBUTION);

    // Approve Ajo contract
    vm.prank(alice);
    token.approve(address(ajo), CONTRIBUTION);

    vm.prank(bob);
    token.approve(address(ajo), CONTRIBUTION);

    // Alice contributes first
    vm.prank(alice);
    ajo.contribute();

    // Bob contributes second
    // This should complete the cycle and trigger the payout to Alice
    vm.prank(bob);
    ajo.contribute();

    // Alice should receive the full cycle pot
    assertEq(
        token.balanceOf(alice),
        CONTRIBUTION * 2
    );

    // The Ajo contract should have no tokens left
    assertEq(
        token.balanceOf(address(ajo)),
        0
    );

    // The cycle should have advanced
    assertEq(
        ajo.currentCycle(),
        2
    );

    // The next cycle should not be closed yet
    assertFalse(ajo.closed());
   }
   function testSecondCyclePaysNextMember() public {
    // Alice and Bob join
    vm.prank(alice);
    ajo.join();

    vm.prank(bob);
    ajo.join();

    // Start the pool
    vm.prank(organizer);
    ajo.startPool();

    // Give both members enough USDC for two cycles
    token.mint(alice, CONTRIBUTION * 2);
    token.mint(bob, CONTRIBUTION * 2);

    // Approve the Ajo contract
    vm.prank(alice);
    token.approve(address(ajo), CONTRIBUTION * 2);

    vm.prank(bob);
    token.approve(address(ajo), CONTRIBUTION * 2);

    // ----- Cycle 1 -----
    vm.prank(alice);
    ajo.contribute();

    vm.prank(bob);
    ajo.contribute();

    // Cycle 1 should have paid Alice
    assertEq(ajo.currentCycle(), 2);

    // ----- Cycle 2 -----
    vm.prank(alice);
    ajo.contribute();

    vm.prank(bob);
    ajo.contribute();

    // Bob should receive the second cycle payout
    assertEq(
        token.balanceOf(bob),
        CONTRIBUTION * 2
    );

    // Pool should now be completed
    assertTrue(ajo.closed());

    // There should be no tokens left in the Ajo contract
    assertEq(
        token.balanceOf(address(ajo)),
        0
    );
   }
   function testCannotCancelBeforeDeadline() public {
    vm.prank(alice);
    ajo.join();

    vm.prank(bob);
    ajo.join();

    vm.prank(organizer);
    ajo.startPool();

    vm.prank(organizer);
    vm.expectRevert(Ajo.ContributionWindowClosed.selector);
    ajo.cancelCycle();
   }
   function testCancelCycleAndClaimRefund() public {
    // Alice and Bob join
    vm.prank(alice);
    ajo.join();

    vm.prank(bob);
    ajo.join();

    // Organizer starts the pool
    vm.prank(organizer);
    ajo.startPool();

    // Give Alice enough USDC
    token.mint(alice, CONTRIBUTION);

    // Alice approves the Ajo contract
    vm.prank(alice);
    token.approve(address(ajo), CONTRIBUTION);

    // Alice contributes
    vm.prank(alice);
    ajo.contribute();

    // Confirm Ajo contract is holding Alice's contribution
    assertEq(
        token.balanceOf(address(ajo)),
        CONTRIBUTION
    );

    // Move time forward by 7 days
    vm.warp(block.timestamp + CYCLE_DURATION);

    // Organizer cancels the incomplete cycle
    vm.prank(organizer);
    ajo.cancelCycle();

    // Cycle should now be cancelled
    assertTrue(ajo.cycleCancelled());

    // Alice claims her refund
    vm.prank(alice);
    ajo.claimRefund();

    // Alice should have received her contribution back
    assertEq(
        token.balanceOf(alice),
        CONTRIBUTION
    );

    // Ajo contract should have no tokens left
    assertEq(
        token.balanceOf(address(ajo)),
        0
    );
  }
  function testNonContributorCannotClaimRefund() public {
    // Alice and Bob join
    vm.prank(alice);
    ajo.join();

    vm.prank(bob);
    ajo.join();

    // Organizer starts the pool
    vm.prank(organizer);
    ajo.startPool();

    // Give Alice USDC
    token.mint(alice, CONTRIBUTION);

    // Alice approves Ajo
    vm.prank(alice);
    token.approve(address(ajo), CONTRIBUTION);

    // Alice contributes
    vm.prank(alice);
    ajo.contribute();

    // Move past the contribution deadline
    vm.warp(block.timestamp + CYCLE_DURATION);

    // Organizer cancels the incomplete cycle
    vm.prank(organizer);
    ajo.cancelCycle();

    // Bob never contributed, so he must not receive a refund
    vm.prank(bob);
    vm.expectRevert(Ajo.RefundUnavailable.selector);
    ajo.claimRefund();
   }
   function testCannotClaimRefundTwice() public {
    // Alice and Bob join
    vm.prank(alice);
    ajo.join();

    vm.prank(bob);
    ajo.join();

    // Organizer starts the pool
    vm.prank(organizer);
    ajo.startPool();

    // Give Alice USDC
    token.mint(alice, CONTRIBUTION);

    // Alice approves Ajo
    vm.prank(alice);
    token.approve(address(ajo), CONTRIBUTION);

    // Alice contributes
    vm.prank(alice);
    ajo.contribute();

    // Move past the contribution deadline
    vm.warp(block.timestamp + CYCLE_DURATION);

    // Organizer cancels the incomplete cycle
    vm.prank(organizer);
    ajo.cancelCycle();

    // Alice claims her refund
    vm.prank(alice);
    ajo.claimRefund();

    // Alice tries to claim the same refund again
    vm.prank(alice);
    vm.expectRevert(Ajo.RefundUnavailable.selector);
    ajo.claimRefund();
   }
   function testOnlyOrganizerCanCancelCycle() public {
    vm.prank(alice);
    ajo.join();

    vm.prank(bob);
    ajo.join();

    vm.prank(organizer);
    ajo.startPool();

    // Move past the contribution deadline
    vm.warp(block.timestamp + CYCLE_DURATION);

    // Alice tries to cancel the cycle
    vm.prank(alice);
    vm.expectRevert(Ajo.NotOrganizer.selector);
    ajo.cancelCycle();
   }
   function testCannotCancelClosedPool() public {
    vm.prank(alice);
    ajo.join();

    vm.prank(bob);
    ajo.join();

    vm.prank(organizer);
    ajo.startPool();

    token.mint(alice, CONTRIBUTION * 2);
    token.mint(bob, CONTRIBUTION * 2);

    vm.prank(alice);
    token.approve(address(ajo), CONTRIBUTION * 2);

    vm.prank(bob);
    token.approve(address(ajo), CONTRIBUTION * 2);

    // Cycle 1
    vm.prank(alice);
    ajo.contribute();

    vm.prank(bob);
    ajo.contribute();

    // Cycle 2
    vm.prank(alice);
    ajo.contribute();

    vm.prank(bob);
    ajo.contribute();

    // Pool is now completely finished.
    assertTrue(ajo.closed());

    vm.prank(organizer);
    vm.expectRevert(Ajo.PoolClosed.selector);
    ajo.cancelCycle();
   }
   function testCurrentRecipient() public {
    vm.prank(alice);
    ajo.join();

    vm.prank(bob);
    ajo.join();

    vm.prank(organizer);
    ajo.startPool();

    // Alice is position 0, so she receives cycle 1.
    assertEq(ajo.getCurrentRecipient(), alice);

    // Give both members enough USDC.
    token.mint(alice, CONTRIBUTION);
    token.mint(bob, CONTRIBUTION);

    vm.prank(alice);
    token.approve(address(ajo), CONTRIBUTION);

    vm.prank(bob);
    token.approve(address(ajo), CONTRIBUTION);

    // Complete cycle 1.
    vm.prank(alice);
    ajo.contribute();

    vm.prank(bob);
    ajo.contribute();

    // Bob is position 1, so he receives cycle 2.
    assertEq(ajo.getCurrentRecipient(), bob);
   }
} 