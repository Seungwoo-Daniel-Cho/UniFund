# Vincent Implementation Notes

## What has been implemented

- Smart contract architecture for one society treasury
- Deployer automatically becomes first committee member
- Committee list set at deployment
- donate(...) for donations without voting rights
- proposeSpending(...) with amount, recipient, reason, fund tag
- executeSpending(...) after objection window

## What has NOT been implemented (by others)

- transferAndJoinMembership() for membership payment
- approveMembership(...) for committee approval
- Membership request expiry logic
- opposeSpending(...) for members/committee
- Rejection if over 50% of committee or regular members object
- Idle treasury / investment allocation feature
- Risk management & reserve allocation functions
