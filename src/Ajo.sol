// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @title Ajo
/// @notice A fixed-member rotating savings pool using an ERC-20 contribution token.
/// @dev Members join in payout order. Each cycle closes when every member has
///      contributed, and the whole cycle pot is sent to that cycle's recipient.
contract Ajo {
    error NotOrganizer();
    error InvalidToken();
    error InvalidContributionAmount();
    error InvalidCycleDuration();
    error InvalidMemberLimit();
    error PoolAlreadyStarted();
    error PoolNotStarted();
    error PoolClosed();
    error AlreadyJoined();
    error MemberLimitReached();
    error NotMember();
    error ContributionAlreadyMade();
    error ContributionWindowClosed();
    error CycleNotComplete();
    error RefundUnavailable();
    error TransferFailed();
    error ReentrantCall();

    struct Member {
        address memberAddress;
        uint256 position;
        uint256 totalContributed;
        bool hasJoined;
    }

    IERC20 public immutable token;
    address public immutable organizer;
    uint256 public immutable contributionAmount;
    uint256 public immutable cycleDuration;
    uint256 public immutable maxMembers;

    uint256 public memberCount;
    /// @notice Current cycle number; zero until the organizer starts the pool.
    uint256 public currentCycle;
    uint256 public cycleStartedAt;
    uint256 public contributionsThisCycle;
    bool public started;
    bool public closed;
    bool public cycleCancelled;

    mapping(address => Member) public members;
    mapping(uint256 => mapping(address => bool)) public contributedInCycle;
    mapping(address => bool) public refundClaimed;
    address[] public memberList;

    uint256 private entered = 1;

    event MemberJoined(address indexed member, uint256 position);
    event PoolStarted(uint256 indexed cycle, uint256 startedAt);
    event ContributionReceived(address indexed member, uint256 indexed cycle, uint256 amount);
    event PayoutSent(address indexed recipient, uint256 indexed cycle, uint256 amount);
    event CycleCancelled(uint256 indexed cycle);
    event RefundClaimed(address indexed member, uint256 indexed cycle, uint256 amount);
    event PoolCompleted(uint256 finalCycle);

    modifier onlyOrganizer() {
        if (msg.sender != organizer) revert NotOrganizer();
        _;
    }

    modifier nonReentrant() {
        if (entered != 1) revert ReentrantCall();
        entered = 2;
        _;
        entered = 1;
    }

    constructor(
        address _token,
        uint256 _contributionAmount,
        uint256 _cycleDuration,
        uint256 _maxMembers
    ) {
        if (_token == address(0)) revert InvalidToken();
        if (_contributionAmount == 0) revert InvalidContributionAmount();
        if (_cycleDuration == 0) revert InvalidCycleDuration();
        if (_maxMembers < 2) revert InvalidMemberLimit();

        token = IERC20(_token);
        organizer = msg.sender;
        contributionAmount = _contributionAmount;
        cycleDuration = _cycleDuration;
        maxMembers = _maxMembers;
    }

    /// @notice Join the pool. Join order determines payout order.
    function join() external {
        if (started) revert PoolAlreadyStarted();
        if (closed) revert PoolClosed();
        if (members[msg.sender].hasJoined) revert AlreadyJoined();
        if (memberCount >= maxMembers) revert MemberLimitReached();

        uint256 position = memberCount;
        members[msg.sender] = Member(msg.sender, position, 0, true);
        memberList.push(msg.sender);
        memberCount++;

        emit MemberJoined(msg.sender, position);
    }

    /// @notice Begin cycle 1 after at least two members have joined.
    function startPool() external onlyOrganizer {
        if (started) revert PoolAlreadyStarted();
        if (closed) revert PoolClosed();
        if (memberCount < 2) revert InvalidMemberLimit();

        started = true;
        currentCycle = 1;
        cycleStartedAt = block.timestamp;
        emit PoolStarted(currentCycle, cycleStartedAt);
    }

    /// @notice Contribute once in the current cycle. All members' contributions
    ///         are transferred directly to that cycle's recipient when complete.
    function contribute() external nonReentrant {
        if (!started) revert PoolNotStarted();
        if (closed) revert PoolClosed();
        if (cycleCancelled) revert PoolClosed();
        if (!members[msg.sender].hasJoined) revert NotMember();
        if (block.timestamp > cycleStartedAt + cycleDuration){ 
            revert ContributionWindowClosed();
    }
        
        if (contributedInCycle[currentCycle][msg.sender]) revert ContributionAlreadyMade();

        contributedInCycle[currentCycle][msg.sender] = true;
        contributionsThisCycle++;
        members[msg.sender].totalContributed += contributionAmount;

        if (!token.transferFrom(msg.sender, address(this), contributionAmount)) revert TransferFailed();
        emit ContributionReceived(msg.sender, currentCycle, contributionAmount);

        if (contributionsThisCycle == memberCount) {
            _payRecipient();
        }
    }

    /// @notice Permanently cancel an incomplete cycle after its contribution window.
    ///         Members can then claim back their contribution for this cycle.
    function cancelCycle() external onlyOrganizer {
    if (!started) revert PoolNotStarted();
    if (closed || cycleCancelled) revert PoolClosed();

    if (block.timestamp < cycleStartedAt + cycleDuration) {
        revert ContributionWindowClosed();
    }

    if (contributionsThisCycle == memberCount) {
        revert CycleNotComplete();
    }

    cycleCancelled = true;
    emit CycleCancelled(currentCycle);
    }

    /// @notice Claim a contribution refund after the organizer cancels a cycle.
    function claimRefund() external nonReentrant {
        if (!cycleCancelled || !contributedInCycle[currentCycle][msg.sender] || refundClaimed[msg.sender]) {
            revert RefundUnavailable();
        }

        refundClaimed[msg.sender] = true;
        if (!token.transfer(msg.sender, contributionAmount)) revert TransferFailed();
        emit RefundClaimed(msg.sender, currentCycle, contributionAmount);
    }

    function getMember(uint256 index) external view returns (address) {
        return memberList[index];
    }
    /// @notice Returns the member who receives the current cycle's payout.
    function getCurrentRecipient() external view returns (address) {
    if (!started || closed) {
        return address(0);
    }

    return memberList[currentCycle - 1];
    }
    function _payRecipient() private {
    uint256 payoutCycle = currentCycle;
    address recipient = memberList[payoutCycle - 1];
    uint256 payout = contributionAmount * memberCount;

    // Advance state before the external token transfer.
    contributionsThisCycle = 0;

    if (currentCycle == memberCount) {
        closed = true;
    } else {
        currentCycle++;
        cycleStartedAt = block.timestamp;
    }

    if (!token.transfer(recipient, payout)) {
        revert TransferFailed();
    }

    emit PayoutSent(recipient, payoutCycle, payout);

    if (closed) {
        emit PoolCompleted(payoutCycle);
    } else {
        emit PoolStarted(currentCycle, cycleStartedAt);
    }
  }     
}