// SPDX-License-Identifier: MIT
// Community Machine – Core Contracts (v0.1)
// ------------------------------------------------------------
// This file contains two Solidity contracts:
// 1. CommunityMachineToken (ERC20Votes) – the on-chain credit used
//    to reward creators & fund projects in the Community Machine DAO.
// 2. IdeaScoreOracle – a lightweight registry where an off-chain AI
//    (or other authorised reporter) posts per-idea scores (0-100)
//    that downstream DAO logic can reference for payouts.
//
// Both contracts are intentionally minimal and MIT-licensed so that
// builders can fork / extend freely. Tested on Solidity ≥0.8.24 and
// OpenZeppelin Contracts v5.*.
// ------------------------------------------------------------
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/*──────────────────────────────────────────────────────────────────────────*
 *  COMMUNITY MACHINE CREDIT (CMC)
 *──────────────────────────────────────────────────────────────────────────*/
contract CommunityMachineToken is ERC20Votes, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /* 1 million premint to deployer for bootstrap grants */
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18;

    constructor()
        ERC20("Community Machine Credit", "CMC")
        ERC20Permit("Community Machine Credit")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /** @notice DAO or authorised module can mint additional credits */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /* ---------- Hook overrides to reconcile voting power ---------- */
    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}

/*──────────────────────────────────────────────────────────────────────────*
 *  IDEA SCORE ORACLE
 *──────────────────────────────────────────────────────────────────────────*/
contract IdeaScoreOracle is AccessControl {
    bytes32 public constant REPORTER_ROLE = keccak256("REPORTER_ROLE");

    struct IdeaReport {
        uint256 score;        // 0–100 composite score
        string  metadataURI;  // off-chain JSON (AI rationale, rubric details)
        uint40  timestamp;    // block timestamp of submission
    }

    mapping(bytes32 => IdeaReport) public reports; // ideaId → report

    event ScoreSubmitted(bytes32 indexed ideaId, uint256 score, string metadataURI);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Submit / update a score for an idea.
     *         `ideaId` can be a keccak256 hash of the proposal slug.
     */
    function submitScore(bytes32 ideaId, uint256 score, string calldata metadataURI)
        external onlyRole(REPORTER_ROLE)
    {
        require(score <= 100, "Score out of bounds");
        reports[ideaId] = IdeaReport({
            score: score,
            metadataURI: metadataURI,
            timestamp: uint40(block.timestamp)
        });
        emit ScoreSubmitted(ideaId, score, metadataURI);
    }

    /** @notice Helper to fetch latest score + age in seconds. */
    function getScore(bytes32 ideaId) external view returns (uint256 score, uint40 ageSec) {
        IdeaReport memory r = reports[ideaId];
        return (r.score, uint40(block.timestamp) - r.timestamp);
    }
}
