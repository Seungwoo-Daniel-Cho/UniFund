// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title UniFundTreasury
 * @notice Blockchain-based crowdfunding and treasury governance system
 *         for university student societies.
 *
 * Project idea:
 * - Student societies can receive membership fees, donations, university grants,
 *   event payments and sponsorships directly into a smart contract treasury.
 * - Committee members are fixed at deployment.
 * - Regular members join by paying a membership fee and are approved by committee.
 * - Committee members can propose treasury spending.
 * - Regular members and committee members can object to spending proposals.
 * - If more than 50% of eligible voters object, the spending request is rejected.
 * - If not rejected, the spending can be executed after the voting period.
 *
 * This supports:
 * - no unilateral control
 * - transparent fundraising
 * - auditable spending proposals
 * - shared governance
 * - Etherscan / MetaMask demo workflow
 */
contract UniFundTreasury is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                        SOCIETY CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    string public societyName;

    uint256 public membershipFee;
    uint256 public membershipDurationBlocks;
    uint256 public votingPeriodBlocks;

    constructor(
        string memory _societyName,
        address[] memory _initialCommittee,
        uint256 _membershipFee,
        uint256 _membershipDurationBlocks,
        uint256 _votingPeriodBlocks
    ) {
        require(bytes(_societyName).length > 0, "Empty society name");
        require(_membershipDurationBlocks > 0, "Invalid membership duration");
        require(_votingPeriodBlocks > 0, "Invalid voting period");

        societyName = _societyName;
        membershipFee = _membershipFee;
        membershipDurationBlocks = _membershipDurationBlocks;
        votingPeriodBlocks = _votingPeriodBlocks;

        // Deployer automatically becomes the first committee member.
        _addCommitteeMember(msg.sender);

        for (uint256 i = 0; i < _initialCommittee.length; i++) {
            _addCommitteeMember(_initialCommittee[i]);
        }

        require(committee.length > 0, "Committee required");
    }

    /*//////////////////////////////////////////////////////////////
                            COMMITTEE
    //////////////////////////////////////////////////////////////*/

    address[] private committee;
    mapping(address => bool) public isCommitteeMember;

    event CommitteeMemberAdded(address indexed member);

    modifier onlyCommittee() {
        require(isCommitteeMember[msg.sender], "Only committee");
        _;
    }

    function _addCommitteeMember(address member) internal {
        require(member != address(0), "Invalid address");

        if (!isCommitteeMember[member]) {
            isCommitteeMember[member] = true;
            committee.push(member);

            emit CommitteeMemberAdded(member);
        }
    }

    function committeeCount() public view returns (uint256) {
        return committee.length;
    }

    function getCommittee() external view returns (address[] memory) {
        return committee;
    }

    /*//////////////////////////////////////////////////////////////
                            MEMBERSHIP
    //////////////////////////////////////////////////////////////*/

    struct Membership {
        bool approved;
        uint256 joinedBlock;
        uint256 expiryBlock;
    }

    struct PendingMembership {
        bool exists;
        uint256 paidAmount;
        uint256 requestedBlock;
    }

    address[] private regularMembers;

    mapping(address => Membership) public memberships;
    mapping(address => PendingMembership) public pendingMemberships;

    event MembershipRequested(
        address indexed applicant,
        uint256 amount,
        uint256 requestedBlock
    );

    event MembershipApproved(
        address indexed member,
        uint256 joinedBlock,
        uint256 expiryBlock
    );

    /**
     * @notice Student pays the membership fee and enters the pending queue.
     * @dev This follows the project idea that membership payment goes directly
     *      into the contract, but committee approval prevents vote hijacking.
     */
    function transferAndJoinMembership() external payable nonReentrant {
        require(!isCommitteeMember[msg.sender], "Committee already eligible");
        require(!isActiveRegularMember(msg.sender), "Already active member");
        require(!pendingMemberships[msg.sender].exists, "Already pending");
        require(msg.value == membershipFee, "Incorrect membership fee");

        pendingMemberships[msg.sender] = PendingMembership({
            exists: true,
            paidAmount: msg.value,
            requestedBlock: block.number
        });

        emit MembershipRequested(msg.sender, msg.value, block.number);
        emit FundsReceived(msg.sender, msg.value, FundSource.MemberFee, "Membership fee");
    }

    /**
     * @notice Committee approves a pending membership request.
     * @dev The member receives voting rights until expiryBlock.
     */
    function approveMembership(address applicant) external onlyCommittee {
        PendingMembership storage pending = pendingMemberships[applicant];

        require(pending.exists, "No pending request");

        delete pendingMemberships[applicant];

        bool wasNeverApproved = memberships[applicant].joinedBlock == 0;

        memberships[applicant] = Membership({
            approved: true,
            joinedBlock: block.number,
            expiryBlock: block.number + membershipDurationBlocks
        });

        if (wasNeverApproved) {
            regularMembers.push(applicant);
        }

        emit MembershipApproved(
            applicant,
            block.number,
            block.number + membershipDurationBlocks
        );
    }

    function isActiveRegularMember(address account) public view returns (bool) {
        Membership memory member = memberships[account];

        return member.approved && block.number <= member.expiryBlock;
    }

    function isEligibleVoter(address account) public view returns (bool) {
        return isCommitteeMember[account] || isActiveRegularMember(account);
    }

    function getRegularMembers() external view returns (address[] memory) {
        return regularMembers;
    }

    /**
     * @notice Counts all currently eligible voters.
     * @dev Committee members are always eligible. Regular members are eligible
     *      only if their membership has not expired.
     *
     *      This loops through regularMembers, which is acceptable for a student
     *      society demo. For a large production system, this should be replaced
     *      by a more gas-efficient membership accounting design.
     */
    function eligibleVoterCount() public view returns (uint256) {
        uint256 count = committee.length;

        for (uint256 i = 0; i < regularMembers.length; i++) {
            address member = regularMembers[i];

            // Avoid double-counting if a committee member also appears in regularMembers.
            if (!isCommitteeMember[member] && isActiveRegularMember(member)) {
                count++;
            }
        }

        return count;
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRIBUTIONS / CROWDFUNDING
    //////////////////////////////////////////////////////////////*/

    enum FundSource {
        Donation,
        MemberFee,
        EventPayment,
        UniversityGrant,
        SponsorGrant
    }

    struct Contribution {
        address contributor;
        uint256 amount;
        FundSource source;
        string purpose;
        uint256 blockNumber;
    }

    uint256 public contributionCount;
    mapping(uint256 => Contribution) public contributions;
    mapping(FundSource => uint256) public totalBySource;

    event FundsReceived(
        address indexed from,
        uint256 amount,
        FundSource indexed source,
        string purpose
    );

    receive() external payable {
        require(msg.value > 0, "No ETH sent");

        _recordContribution(
            msg.sender,
            msg.value,
            FundSource.Donation,
            "Direct transfer"
        );
    }

    function donate(string calldata purpose) external payable {
        require(msg.value > 0, "No ETH sent");

        _recordContribution(
            msg.sender,
            msg.value,
            FundSource.Donation,
            purpose
        );
    }

    function contribute(
        FundSource source,
        string calldata purpose
    ) external payable {
        require(msg.value > 0, "No ETH sent");

        _recordContribution(
            msg.sender,
            msg.value,
            source,
            purpose
        );
    }

    function _recordContribution(
        address contributor,
        uint256 amount,
        FundSource source,
        string memory purpose
    ) internal {
        contributionCount++;

        contributions[contributionCount] = Contribution({
            contributor: contributor,
            amount: amount,
            source: source,
            purpose: purpose,
            blockNumber: block.number
        });

        totalBySource[source] += amount;

        emit FundsReceived(contributor, amount, source, purpose);
    }

    function treasuryBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /*//////////////////////////////////////////////////////////////
                        SPENDING GOVERNANCE
    //////////////////////////////////////////////////////////////*/

    struct SpendingRequest {
        string description;
        string category;
        uint256 amount;
        address payable recipient;
        address proposer;
        uint256 proposedBlock;
        uint256 expiryBlock;
        uint256 eligibleVoterSnapshot;
        bool executed;
    }

    uint256 public requestCount;
    mapping(uint256 => SpendingRequest) public requests;

    mapping(uint256 => mapping(address => bool)) public hasOpposedSpending;
    mapping(uint256 => uint256) public spendingOppositionCount;

    event SpendingProposed(
        uint256 indexed id,
        address indexed proposer,
        string description,
        string category,
        uint256 amount,
        address indexed recipient,
        uint256 proposedBlock,
        uint256 expiryBlock,
        uint256 eligibleVoterSnapshot
    );

    event SpendingOpposed(
        uint256 indexed id,
        address indexed objector,
        uint256 oppositionCount
    );

    event SpendingExecuted(
        uint256 indexed id,
        address indexed recipient,
        uint256 amount
    );

    modifier validRequest(uint256 requestId) {
        require(requestId > 0 && requestId <= requestCount, "Invalid request");
        _;
    }

    /**
     * @notice Committee proposes a treasury withdrawal.
     *
     * Example categories:
     * - "Event venue"
     * - "Guest speaker"
     * - "Marketing"
     * - "University-approved budget"
     * - "Sponsor-funded activity"
     */
    function proposeSpending(
        string calldata description,
        string calldata category,
        uint256 amount,
        address payable recipient
    ) external onlyCommittee {
        require(bytes(description).length > 0, "Empty description");
        require(bytes(category).length > 0, "Empty category");
        require(amount > 0, "Invalid amount");
        require(recipient != address(0), "Invalid recipient");

        uint256 voters = eligibleVoterCount();
        require(voters > 0, "No eligible voters");

        requestCount++;

        uint256 expiryBlock = block.number + votingPeriodBlocks;

        requests[requestCount] = SpendingRequest({
            description: description,
            category: category,
            amount: amount,
            recipient: recipient,
            proposer: msg.sender,
            proposedBlock: block.number,
            expiryBlock: expiryBlock,
            eligibleVoterSnapshot: voters,
            executed: false
        });

        emit SpendingProposed(
            requestCount,
            msg.sender,
            description,
            category,
            amount,
            recipient,
            block.number,
            expiryBlock,
            voters
        );
    }

    /**
     * @notice Any eligible voter can oppose a spending request.
     *
     * Eligible voters:
     * - committee members
     * - approved regular members whose membership has not expired
     *
     * Design rationale:
     * - The default is "not rejected" so inactive members do not paralyse the society.
     * - If more than 50% of eligible voters object, the request is blocked.
     * - Each eligible voter can oppose each request only once.
     */
    function opposeSpending(
        uint256 requestId
    ) external validRequest(requestId) {
        SpendingRequest storage req = requests[requestId];

        require(isEligibleVoter(msg.sender), "Not eligible voter");
        require(!req.executed, "Already executed");
        require(block.number <= req.expiryBlock, "Voting ended");
        require(
            !hasOpposedSpending[requestId][msg.sender],
            "Already opposed"
        );

        hasOpposedSpending[requestId][msg.sender] = true;
        spendingOppositionCount[requestId]++;

        emit SpendingOpposed(
            requestId,
            msg.sender,
            spendingOppositionCount[requestId]
        );
    }

    /**
     * @notice Returns true if more than 50% of eligible voters objected.
     *
     * The denominator is frozen at proposal creation using eligibleVoterSnapshot.
     * This prevents the threshold from changing after the proposal is created.
     */
    function isSpendingRejected(
        uint256 requestId
    ) public view validRequest(requestId) returns (bool) {
        SpendingRequest storage req = requests[requestId];

        return spendingOppositionCount[requestId] * 2 > req.eligibleVoterSnapshot;
    }

    /**
     * @notice Executes a spending request after the voting period.
     *
     * Conditions:
     * - request exists
     * - request has not been executed
     * - voting period has ended
     * - treasury has enough ETH
     * - request has not been rejected by more than 50% objection
     *
     * Security:
     * - nonReentrant protects against reentrancy
     * - state is updated before external ETH transfer
     * - low-level call result is checked
     */
    function executeSpending(
        uint256 requestId
    ) external nonReentrant validRequest(requestId) {
        SpendingRequest storage req = requests[requestId];

        require(!req.executed, "Already executed");
        require(block.number > req.expiryBlock, "Voting not ended");
        require(req.amount <= address(this).balance, "Insufficient balance");
        require(!isSpendingRejected(requestId), "Rejected by voters");

        req.executed = true;

        (bool success, ) = req.recipient.call{value: req.amount}("");
        require(success, "Transfer failed");

        emit SpendingExecuted(requestId, req.recipient, req.amount);
    }

    /*//////////////////////////////////////////////////////////////
                        DEMO HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getSpendingRequest(
        uint256 requestId
    )
        external
        view
        validRequest(requestId)
        returns (
            string memory description,
            string memory category,
            uint256 amount,
            address recipient,
            address proposer,
            uint256 proposedBlock,
            uint256 expiryBlock,
            uint256 eligibleVoterSnapshot,
            uint256 oppositionCount,
            bool rejected,
            bool executed
        )
    {
        SpendingRequest storage req = requests[requestId];

        return (
            req.description,
            req.category,
            req.amount,
            req.recipient,
            req.proposer,
            req.proposedBlock,
            req.expiryBlock,
            req.eligibleVoterSnapshot,
            spendingOppositionCount[requestId],
            isSpendingRejected(requestId),
            req.executed
        );
    }

    /*//////////////////////////////////////////////////////////////
                FUTURE DEVELOPMENT PLACEHOLDERS
    //////////////////////////////////////////////////////////////*/

    /**
     * Future feature 1: Milestone-based sponsor funding
     * - Sponsor locks funding
     * - Society receives each tranche only after reaching agreed targets
     *
     * Future feature 2: Refundable campaigns
     * - If funding goal is not reached before deadline, contributors can refund
     *
     * Future feature 3: Society track record
     * - Public record of funding success, spending discipline and execution history
     *
     * Future feature 4: Joint society treasury
     * - Multiple societies co-manage one shared event fund
     *
     * Future feature 5: Idle treasury / reserve allocation
     * - Daniel can implement reserve ratio and low-risk allocation logic here
     */
}