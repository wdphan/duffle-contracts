// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

import "./Forum.sol";
import "https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol";

contract ForumProxy is CloneFactory {
    address public admin;
      address public implementation;

      address [] public cloneContracts;

        // stores the address of the implementation and msg.sender
      function StorageFactory(address _implementation) public {
          implementation = _implementation;
          admin = msg.sender;
      }


        // function that creates the clone
        // arguments would go here
      function createStorage () external {
          require(msg.sender == admin,  'Only admin can clone contract');
          address clone = createClone(implementation);
        // Storage(clone).init(myArg) - how to initialize clone if needed
        
        // create clone of storage smart contract
        cloneContracts.push(clone);
      
  }

    function getClones(uint i) view external returns (address) {
        return cloneContracts[i];
    }
    function getCloneList() view external returns (address [] memory) {
        return cloneContracts;
    }
} 