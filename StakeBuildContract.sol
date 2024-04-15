// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract StakeBuildContract {

    uint256 internal MUL_BASE=10**18;
    uint256 public global_keys;
    uint256 public global_mask;

    mapping(address => uint256) user_keys;
    mapping(address => uint256) user_mask;

    function add_profit(uint256 amount) public returns (bool) {
        if(global_keys>0){
            uint256 profitPerKey = MUL_BASE * amount / global_keys;
            global_mask+=profitPerKey;
        }else{

        }
        return true;
    }

    function add_share(address user, uint256 amount) public returns (bool) {
        global_keys += amount;
        user_keys[user]+=amount;
        user_mask[user]+=global_mask*amount;
        return true;
    }

    function get_profit(address user) public returns (uint256) {
        uint256 profit = (global_mask * user_keys[user] - user_mask[user]) / MUL_BASE;
        return profit;
    }

    function withdraw(address user) public returns (uint256) {
        uint256 profit = (global_mask * user_keys[user] - user_mask[user]) / MUL_BASE;
        user_mask[user] = global_mask * user_keys[user];
        return profit;
    }

    function quit(address user) public returns (uint256) {
        uint256 profit = (global_mask * user_keys[user] - user_mask[user]) / MUL_BASE;
        global_keys -= user_keys[user];
        user_mask[user] = 0;
        user_keys[user] = 0;
        return profit;
    }
}
