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
    uint256 public global_profit;
    uint256 public dev_fee=5;

    mapping(address => uint256) public user_keys;
    mapping(address => uint256) public user_mask;

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

    function withdraw() public returns (uint256) {
        address user = msg.sender;
        uint256 profit = (global_mask * user_keys[user] - user_mask[user]) / MUL_BASE;
        user_mask[user] = global_mask * user_keys[user];
        require(address(this).balance >= profit,"eth not enough");
        payable(user).transfer(profit);
        return profit;
    }

    function quit() public returns (uint256) {
        address user = msg.sender;
        uint256 profit = (global_mask * user_keys[user] - user_mask[user]) / MUL_BASE;
        global_keys -= user_keys[user];
        uint256 stoken_amount = user_keys[user] * 1;
        user_mask[user] = 0;
        user_keys[user] = 0;
        require(IERC20(stoken).balanceOf(address(this)) >= stoken_amount, "stoken amount not enough");
        IERC20(stoken).transfer(user, stoken_amount);
        require(address(this).balance >= profit,"eth not enough");
        payable(user).transfer(profit);
        return profit;
    }

    function query_profit(address user) public view returns (uint256) {
        uint256 profit = (global_mask * user_keys[user] - user_mask[user]) / MUL_BASE;
        return profit;
    }

    function add_profit() public payable returns (bool) {
        uint256 amount = msg.value;
        if(amount>0){
            global_profit += amount;
            if(global_keys>0){
                uint256 dev_amount = amount / dev_fee;
                uint256 share_amount = amount - dev_amount;
                uint256 profitPerKey = MUL_BASE * share_amount / global_keys;
                global_mask+=profitPerKey;
                payable(owner).transfer(dev_amount);
            }else{
                //no any stake
                payable(owner).transfer(amount);
            }
        }
        return true;
    }

    function setStoken(address _stoken) external onlyOwner {
        stoken = _stoken;
    }

    function setDevFee(uint256 _dev_fee) external onlyOwner {
        dev_fee = _dev_fee;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    receive() external payable {
        if(msg.sender == tx.origin){
            //user send any amount eth to quit
            quit();
            payable(msg.sender).transfer(msg.value);
        }else{
            add_profit();
        }
    }
}