// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * UniFundTreasury
 * Vincent's responsibility:
 * - Treasury storage
 * - Spending proposal lifecycle
 * - Committee-based governance shell
 *
 * Placeholders are left for:
 * - Membership & voting logic (Lucas)
 * - Idle treasury / investment / risk management logic (Daniel)
 */
contract UniFundTreasury is ReentrancyGuard {

    /*//////////////////////////////////////////////////////////////
                        COMMITTEE & SOCIETY CONFIG
    //////////////////////////////////////////////////////////////*/

    string public societyName;

    uint256 public membershipFee;
    uint256 public membershipDuration;
    uint256 public votingPeriodBlocks;

    address[] public committee;
    mapping(address => bool) public isCommitteeMember;

    modifier onlyCommittee() {
        require(isCommitteeMember[msg.sender], "Only committee");
        _;
    }

    constructor(
        string memory _societyName,
        address[] memory _committee,
        uint256 _membershipFee,
        uint256 _membershipDuration,
        uint256 _votingPeriodBlocks
    ) {
        require(bytes(_societyName).length > 0, "Empty society name");
        require(_membershipDuration > 0, "Invalid membership duration");
        require(_votingPeriodBlocks > 0, "Invalid voting period");

        societyName = _societyName;
        membershipFee = _membershipFee;
        membershipDuration = _membershipDuration;
        votingPeriodBlocks = _votingPeriodBlocks;

        // deployer becomes first committee member
        _addCommittee(msg.sender);

        for (uint256 i = 0; i < _committee.length; i++) {
            _addCommittee(_committee[i]);
        }

        require(committee.length > 0, "Committee required");
    }

    function _addCommittee(address member) internal {
        require(member != address(0), "Invalid address");
        if (!isCommitteeMember[member]) {
            isCommitteeMember[member] = true;
            committee.push(member);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            MEMBERSHIP
    //////////////////////////////////////////////////////////////*/

    /**
     * Placeholder:
     * - transferAndJoinMembership() for membership payment (Lucas)
     * - approveMembership(...) for committee approval (Lucas)
     * - Membership request expiry logic (Lucas)
     */

    /*//////////////////////////////////////////////////////////////
                            TREASURY
    //////////////////////////////////////////////////////////////*/

    event FundsReceived(address indexed from, uint256 amount);

    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    function donate() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    function treasuryBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /*//////////////////////////////////////////////////////////////
                      SPENDING GOVERNANCE
    //////////////////////////////////////////////////////////////*/

    struct SpendingRequest {
        string description;
        uint256 amount;
        address payable recipient;
        uint256 expiryBlock;
        bool executed;
    }

    uint256 public requestCount;
    mapping(uint256 => SpendingRequest) public requests;

    event SpendingProposed(
        uint256 indexed id,
        string description,
        uint256 amount,
        address recipient
    );

    event SpendingExecuted(
        uint256 indexed id,
        address recipient,
        uint256 amount
    );

    function proposeSpending(
        string calldata description,
        uint256 amount,
        address payable recipient
    ) external onlyCommittee {
        require(amount > 0, "Invalid amount");
        require(recipient != address(0), "Invalid recipient");

        requestCount++;
        requests[requestCount] = SpendingRequest({
            description: description,
            amount: amount,
            recipient: recipient,
            expiryBlock: block.number + votingPeriodBlocks,
            executed: false
        });

        emit SpendingProposed(requestCount, description, amount, recipient);
    }

    /**
     * Placeholder:
     * - opposeSpending(...) for ONLY members/committee (Lucas)
     */

    function executeSpending(uint256 requestId) external nonReentrant {
        SpendingRequest storage req = requests[requestId];

        require(!req.executed, "Already executed");
        require(block.number > req.expiryBlock, "Voting not ended");
        require(req.amount <= address(this).balance, "Insufficient balance");

        /**
        * Placeholder:
        * - Rejection if over 50% of committee or regular members object (Lucas)
        */

        req.executed = true;
        req.recipient.transfer(req.amount);

        emit SpendingExecuted(requestId, req.recipient, req.amount);
    }

    /*//////////////////////////////////////////////////////////////
            Idle treasury / investment allocation feature
            Risk management & reserve allocation functions
    //////////////////////////////////////////////////////////////*/

    /**
     * Daniel will implement:
     * - Idle treasury / investment allocation feature (Daniel)
     * - Risk management & reserve allocation functions (Daniel)
     */
}
