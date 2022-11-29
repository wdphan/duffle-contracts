// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

/// @title Voting with delegation.
contract Forum {
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
    struct Solution {
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

    PollStatus public status;
    // owner of deployed contract
    address public chairperson;
    uint public pollEnd;
    string public question;
    uint public durationMinutes;
    string public groupName;
    string public groupDescription;

    event Received(address, uint);
    event PollResult(address creator, bytes32 title, string description, uint voteCount);
    event PaidWinningProposalCreator(address creator, uint amountPaidOut);
    event PaidVoters(address chairperson, address payable [] voters, uint amountPaidOut);
    event PaidProposalCreators(address chairperson, uint amountPaidOut);

    // This declares a state variable that
    // stores a `Voter` struct for each possible address.
    mapping(address => Voter) public voters;
    
    // A dynamically-sized array of `Proposal` structs.
    Solution [] public solutions;
    address payable[] public allVoters;

     // allow the contract to receive funds
     receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    // Create the group name and description!
    constructor(string memory _groupName, string memory _groupDescription) payable {
        chairperson = msg.sender;
        voters[chairperson].weight = 1;
       
       _groupName = groupName;
       _groupDescription = groupDescription;
    }

    // create any questions for group
    function createQuestion (string memory _question, uint256 _durationMinutes) external payable {
         durationMinutes = _durationMinutes;
          question = _question;
            // sets time duration
            pollEnd = block.timestamp + (durationMinutes * 1 minutes);
    }

    // SAMPLE TITLES:
    // console.log(Web3.utils.asciiToHex("foo")); = 0x666f6f
    // console.log(Web3.utils.asciiToHex("bar")); = 0x626172
    // ["0x666f6f0000000000000000000000000000000000000000000000000000000000", 
    // "0x6261720000000000000000000000000000000000000000000000000000000000"]

    ////////////////
    /// CHAIRMAN ///
    ////////////////

    // create a possible solution/answer for the current question with title, description
    // starts with 0 votes
    function proposeSolution(bytes32 _title, string memory _description) external {
        // For each of the provided proposal names,
        // create a new proposal object and add it
        // to the end of the array.
  
            // `Proposal({...})` creates a temporary
            // Proposal object and `proposals.push(...)`
            // appends it to the end of `proposals`.
            solutions.push(Solution({
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

    //////////////
    /// VOTERS ///
    //////////////

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
            solutions[delegate_.vote].voteCount += sender.weight;
        } else {
            // If the delegate did not vote yet,
            // add to her weight.
            delegate_.weight += sender.weight;
        }
    }

    /// Give your vote (including votes delegated to you)
    /// to proposal `proposals[proposal].name`.
    function vote(uint solution) external {
        Voter storage sender = voters[msg.sender];
        require(sender.weight != 0, "Has no right to vote");
        require(!sender.voted, "Already voted.");
        sender.voted = true;
        sender.vote = solution;

        // If `proposal` is out of the range of the array,
        // this will throw automatically and revert all
        // changes.
        solutions[solution].voteCount += sender.weight;
    }

     // display all proposals from proposals array
    function getAllSolutions() external view returns(Solution[] memory) {
        Solution[] memory items = new Solution[](solutions.length);
        for(uint i = 0; i < solutions.length; i++) {
            items[i] = solutions[i];
        }
        return items;
    }

    /////////////////////////////
    /// WINNING PROPOSAL INFO ///
    /////////////////////////////

     /// @dev Computes the winning proposal index taking all
    /// previous votes into account.
    function winningSolutionIndex() private view
            returns (uint winningSolution_)
    {
        uint winningVoteCount = 0;
        for (uint p = 0; p < solutions.length; p++) {
            // if total votes are greater than 0, then
            // set the total vote count of the proposal with most votes
            // to winner
            if (solutions[p].voteCount > winningVoteCount) {
                winningVoteCount = solutions[p].voteCount;
                winningSolution_ = p;
            }
        }
    }

    // provides the creator address of the winning proposal
    function winningSolutionCreatorAddress() external view
            returns (address winningSolution_)
    {
        // grabs index and logs title of winning proposal
        winningSolution_ = solutions[winningSolutionIndex()].creator;
    }

    // Calls winningSolutionIndex() function to get the index
    // of the winner contained in the proposals array and then
    // returns the title of the winning proposal
    function winningSolutionTitle() external view
            returns (bytes32 winningSolution_)
    {
        // grabs index and logs title of winning proposal
        winningSolution_ = solutions[winningSolutionIndex()].title;
    }

    function winningSolutionDescription() external view
            returns (string memory winningSolution_)
    {
        // grabs index and logs description of winning proposal
        winningSolution_ = solutions[winningSolutionIndex()].description;
    }

    function winningSolutionVoteCount() external view
            returns (uint winningSolution_)
    {
        // grabs index and logs title of winning proposal
        winningSolution_ = solutions[winningSolutionIndex()].voteCount;
    }

    ////////////////////////
    /// END POLL METHODS ///
    ////////////////////////

    // chairperson can end poll
    // when poll ends, the winning proposal's creator
    // will receive any funds deposited in poll as prize for best proposal
    function endPoll() external payable {
        // sets the poll state to inactive
        status = PollStatus.INACTIVE;
        // requires chairperson
        require(msg.sender == chairperson);
        // requires time to run out
        require(block.timestamp >= pollEnd);
    }

    // CHECK FUCTIONS BELOW!!!

    // ends the poll and pays the address who created the winner proposal
    function endPollAndPayWinningSolutionCreator () external payable {
         // sets the contract balance
        uint contractBalance = address(this).balance;
        for(uint i=0; i < solutions.length; i++) {
           emit PollResult(solutions[winningSolutionIndex()].creator, solutions[winningSolutionIndex()].title, solutions[winningSolutionIndex()].description, solutions[winningSolutionIndex()].voteCount);
        }
        address creator = solutions[winningSolutionIndex()].creator;

        payable(creator).transfer(contractBalance);

        emit PaidWinningProposalCreator(creator, contractBalance);
    }

    // Ends the poll and pays all voters who have participated evenly
    function endPollAndPayAllVoters () external payable {
    uint contractBalance = address(this).balance;
    uint256 share = contractBalance / allVoters.length;
    for (uint i=0; i< allVoters.length; i++){
             allVoters[i].transfer(share);
         }
    emit PaidVoters(chairperson, allVoters, contractBalance);
    }

    // Ends the poll and pays solution creators evenly
    function endPollAndPaySolutionCreators () external {
    uint contractBalance = address(this).balance;
    uint256 share = contractBalance / solutions.length;
    for (uint i=0; i< solutions.length; i++){
             solutions[i].creator.transfer(share);
         }
    emit PaidProposalCreators(chairperson, contractBalance);
    }
}