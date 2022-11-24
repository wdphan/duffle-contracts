// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
/// @title Voting with delegation.
contract Ballot {
    // This declares a new complex type which will
    // be used for variables later.
    // It will represent a single voter.
    struct Voter {
        uint weight; // weight is accumulated by delegation
        bool voted;  // if true, that person already voted
        address delegate; // person delegated to
        uint vote;   // index of the voted proposal
    }

    // This is a type for a single proposal.
    struct Proposal {
        address payable creator;
        bytes32 title;   // short name (up to 32 bytes)
        string description;   // short description (up to 32 bytes)
        uint voteCount; // number of accumulated votes
    }

    // status of poll
    // Returns uint
    // ACTIVE - 0
    // INACTIVE - 1
    enum PollStatus{ ACTIVE, INACTIVE }

    // owner of deployed contract
    address public chairperson;
    uint public pollEnd;
    string public question;
    uint public durationMinutes;
    PollStatus public status;

    event Received(address, uint);
    event PollResult(address creator, bytes32 title, string description, uint voteCount);
    event PaidWinningProposalCreator(address creator, uint amountPaid);

    // This declares a state variable that
    // stores a `Voter` struct for each possible address.
    mapping(address => Voter) public voters;

    // A dynamically-sized array of `Proposal` structs.
    Proposal[] public proposals;

    // Create a new ballot to choose one of `proposalNames`.
    constructor(string memory _question, uint256 _durationMinutes) payable {
        chairperson = msg.sender;
        voters[chairperson].weight = 1;
        durationMinutes = _durationMinutes;
        question = _question;
        // sets time duration
        pollEnd = block.timestamp + (durationMinutes * 1 minutes);
    }

    // console.log(Web3.utils.asciiToHex("foo")); = 0x666f6f
    // console.log(Web3.utils.asciiToHex("bar")); = 0x626172
    // ["0x666f6f0000000000000000000000000000000000000000000000000000000000", 
    // "0x6261720000000000000000000000000000000000000000000000000000000000"]

    // allow the contract to receive funds
     receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    // create proposals for the current question with title, descriptio
    // starts with 0 votes
    function createProposal(bytes32 _title, string memory _description) external {
        // For each of the provided proposal names,
        // create a new proposal object and add it
        // to the end of the array.
  
            // `Proposal({...})` creates a temporary
            // Proposal object and `proposals.push(...)`
            // appends it to the end of `proposals`.
             proposals.push(Proposal({
                creator: payable(msg.sender),
                title: _title,
                description: _description,
                voteCount: 0
            }));
        
    }

    // Give `voter` the right to vote on this ballot.
    // May only be called by `chairperson`.
    function giveRightToVote(address voter) external {
        // If the first argument of `require` evaluates
        // to `false`, execution terminates and all
        // changes to the state and to Ether balances
        // are reverted.
        // This used to consume all gas in old EVM versions, but
        // not anymore.
        // It is often a good idea to use `require` to check if
        // functions are called correctly.
        // As a second argument, you can also provide an
        // explanation about what went wrong.
        require(
            msg.sender == chairperson,
            "Only chairperson can give right to vote."
        );
        require(
            !voters[voter].voted,
            "The voter already voted."
        );
        require(voters[voter].weight == 0);
        voters[voter].weight = 1;
    }

    /// Delegate your vote to the voter `to`.
    function delegateVote(address to) external {
        // assigns reference
        Voter storage sender = voters[msg.sender];
        require(sender.weight != 0, "You have no right to vote");
        require(!sender.voted, "You already voted.");

        require(to != msg.sender, "Self-delegation is disallowed.");

        // Forward the delegation as long as
        // `to` also delegated.
        // In general, such loops are very dangerous,
        // because if they run too long, they might
        // need more gas than is available in a block.
        // In this case, the delegation will not be executed,
        // but in other situations, such loops might
        // cause a contract to get "stuck" completely.
        while (voters[to].delegate != address(0)) {
            to = voters[to].delegate;

            // We found a loop in the delegation, not allowed.
            require(to != msg.sender, "Found loop in delegation.");
        }

        Voter storage delegate_ = voters[to];

        // Voters cannot delegate to accounts that cannot vote.
        require(delegate_.weight >= 1);

        // Since `sender` is a reference, this
        // modifies `voters[msg.sender]`.
        sender.voted = true;
        sender.delegate = to;

        if (delegate_.voted) {
            // If the delegate already voted,
            // directly add to the number of votes
            proposals[delegate_.vote].voteCount += sender.weight;
        } else {
            // If the delegate did not vote yet,
            // add to her weight.
            delegate_.weight += sender.weight;
        }
    }

    /// Give your vote (including votes delegated to you)
    /// to proposal `proposals[proposal].name`.
    function vote(uint proposal) external {
        Voter storage sender = voters[msg.sender];
        require(sender.weight != 0, "Has no right to vote");
        require(!sender.voted, "Already voted.");
        sender.voted = true;
        sender.vote = proposal;

        // If `proposal` is out of the range of the array,
        // this will throw automatically and revert all
        // changes.
        proposals[proposal].voteCount += sender.weight;
    }

    // display all proposals from proposals array
    function getAllProposals() external view returns(Proposal[] memory) {
        Proposal[] memory items = new Proposal[](proposals.length);
        for(uint i = 0; i < proposals.length; i++) {
            items[i] = proposals[i];
        }
        return items;
    }

    /// @dev Computes the winning proposal index taking all
    /// previous votes into account.
    function winningProposalIndex() private view
            returns (uint winningProposal_)
    {
        uint winningVoteCount = 0;
        for (uint p = 0; p < proposals.length; p++) {
            if (proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposal_ = p;
            }
        }
    }

    // Calls winningProposalIndex() function to get the index
    // of the winner contained in the proposals array and then
    // returns the title of the winning proposal
    function winningProposal() external view
            returns (bytes32 winnerName_)
    {
        winnerName_ = proposals[winningProposalIndex()].title;
    }


    // chairperson can end poll
    // when poll ends, the winning proposal's creator
    // will receive any funds deposited in poll as prize for best proposal
    function endPoll() external payable {
        // sets the poll state to inactive
        status = PollStatus.INACTIVE;
        // sets the contract balance
        uint contractBalance = address(this).balance;

        // requires chairperson
        require(msg.sender == chairperson);
        // requires time to run out
        require(block.timestamp >= pollEnd);

        for(uint i=0; i < proposals.length; i++) {
           emit PollResult(proposals[winningProposalIndex()].creator, proposals[winningProposalIndex()].title, proposals[winningProposalIndex()].description, proposals[winningProposalIndex()].voteCount);
        }

        address creator = proposals[winningProposalIndex()].creator;

        payable(creator).transfer(contractBalance);

        emit PaidWinningProposalCreator(creator, contractBalance);
    }

}