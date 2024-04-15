// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function balanceOf(address user) external view returns (uint256 balance);

    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract Stake314 {

    address owner;
    address x314;
    uint256 internal MUL_BASE=10**18;
    uint256 public global_keys;
    uint256 public global_mask;

    mapping(address => uint256) user_keys;
    mapping(address => uint256) user_mask;

    constructor(address _x314) {
        owner = msg.sender;
        x314 = _x314;
    }

    function add_profit(uint256 amount) internal returns (bool) {
        if(global_keys>0){
            uint256 profitPerKey = MUL_BASE * amount / global_keys;
            global_mask+=profitPerKey;
        }else{

        }
        return true;
    }

    function stake(address user, uint256 amount) public returns (bool) {
        require(msg.sender==x314,"auth fail!");
        global_keys += amount;
        user_keys[user]+=amount;
        user_mask[user]+=global_mask*amount;
        return true;
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

    function query_profit(address user) public returns (uint256) {
        uint256 profit = (global_mask * user_keys[user] - user_mask[user]) / MUL_BASE;
        return profit;
    }
}
