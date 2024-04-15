// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function balanceOf(address user) external view returns (uint256 balance);

    event Transfer(address indexed from, address indexed to, uint256 value);
}

interface IStakeContract {
    function stake(address user, uint256 amount) external returns (bool);
}

contract FeeDistributor {
    address public owner;
    address public x314;
    address public stoken;
    //
    uint256 internal MUL_BASE = 10 ** 18;
    uint256 public global_keys;
    uint256 public global_mask;

    mapping(address => uint256) user_keys;
    mapping(address => uint256) user_mask;

    constructor(address _x314,address _stoken) {
        owner = msg.sender;
        x314 = _x314;
        stoken = _stoken;
    }

    function stake(address user, uint256 amount) public returns (bool) {
        require(msg.sender==stoken,"auth fail!");
        global_keys += amount;
        user_keys[user]+=amount;
        user_mask[user]+=global_mask*amount;
        return true;
    }

    function withdraw(address user) public returns (uint256) {
        require(msg.sender==user,"auth fail");
        uint256 profit = (global_mask * user_keys[user] - user_mask[user]) / MUL_BASE;
        user_mask[user] = global_mask * user_keys[user];
        require(address(this).balance >= profit,"eth not enough");
        payable(user).transfer(profit);
        return profit;
    }

    function quit(address user) public returns (uint256) {
        require(msg.sender==user,"auth fail");
        uint256 profit = (global_mask * user_keys[user] - user_mask[user]) / MUL_BASE;
        global_keys -= user_keys[user];
        uint256 stoken_amount = user_keys[user] * 1;
        user_mask[user] = 0;
        user_keys[user] = 0;
        require(address(this).balance >= profit,"eth not enough");
        payable(user).transfer(profit);
        require(IERC20(stoken).balanceOf(address(this)) >= stoken_amount, "stoken amount not enough");
        IERC20(stoken).transfer(user, stoken_amount);
        return profit;
    }

    function query_profit(address user) public view returns (uint256) {
        uint256 profit = (global_mask * user_keys[user] - user_mask[user]) / MUL_BASE;
        return profit;
    }

    function add_profit() public payable returns (bool) {
        uint256 amount = msg.value;
        if(amount>0){
            if(global_keys>0){
                uint256 profitPerKey = MUL_BASE * amount / global_keys;
                global_mask+=profitPerKey;
            }else{
                //没有质押的情况
                payable(owner).transfer(amount);
            }
        }
        return true;
    }

    function setStoken(address _stoken) external onlyOwner {
        stoken = _stoken;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    receive() external payable {
        if(msg.sender == tx.origin){
            //用户转账任意额度，退出质押
            quit(msg.sender);
            payable(owner).transfer(msg.value);
        }else{
            //其他情况增加分红
            add_profit();
        }
    }
}
