// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

// each deployed ballot will be a community
// functionality of the community will be enabled through the ballot
// contract

import "src/Forum.sol";

contract ForumFactory {
    // stores ids of ballots created
    Forum[] public forums;
    uint public forumCount;

    // deploy contract by inserting parameters for constructor
    function deployForumContract(string memory _groupName, string memory _groupDescription) payable public {
        // Ballot ballot = new Ballot(_question,_durationMinutes); -- method that doesn't send ETH
        Forum forum = (new Forum){value: msg.value}(_groupName, _groupDescription);
        forums.push(forum);
        // increases forum count by 1
        forumCount += 1;
    }

    // get all deployed factory contracts
    function getAllForums() external view returns(Forum[] memory) {
        Forum[] memory items = new Forum[](forums.length);
        for(uint i = 0; i < forums.length; i++) {
            items[i] = forums[i];
        }
        return items;
 }
}