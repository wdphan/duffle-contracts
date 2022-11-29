// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./Ballot.sol";

// each deployed ballot will be a community
// functionality of the community will be enabled through the ballot
// contract

contract BallotFactory {
    // stores ids of ballots created
    Ballot[] public ballots;

    // deploy contract by inserting parameters for constructor
    function deployBallotContract(string memory _question, uint256 _durationMinutes) payable public {
        // Ballot ballot = new Ballot(_question,_durationMinutes); -- method that doesn't send ETH
        Ballot ballot = (new Ballot){value: msg.value}(_question,_durationMinutes);
        ballots.push(ballot);
    }

        // get list of factory contracts
    //    function getChildren() external view returns(Child[] memory _children){
    //    _children = new Child[](children.length- disabledCount);
    //    uint count;
    //    for(uint i=0;i<children.length; i++){
    //       if(children[i].isEnabled()){
    //          _children[count] = children[i];
    //          count++;
    //       }

}