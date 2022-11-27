// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import {IWETH} from "./interfaces/IWETH.sol";





contract dsa {


    constructor() public {}

    receive() external payable {}

  function callF() public  returns (uint) {
     uint result = addLiquidityETH();
     return result ;
  }

    function addLiquidityETH() public view returns (uint)  {

  if(msg.sender == address(this) ){
      return 5;
  } else {
      return 3;
  }
    }


}

    


