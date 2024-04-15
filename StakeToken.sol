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

contract StakeToken {
    address public owner;
    string public name = "stoken";
    uint256 public decimals = 18;
    string public symbol = "stoken";
    uint256 public totalSupply;
    uint256 public historySupply;
    uint256 public maxSupply;

    uint256 public startMintBlock;
    uint256 public lastMintBlock;

    address public x314;
    address public fee_distributor;
    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) internal allowed;

    //
    uint256 internal MUL_BASE = 10 ** 18;
    uint256 public global_keys;
    uint256 public global_mask;

    mapping(address => uint256) user_keys;
    mapping(address => uint256) user_mask;

    //
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed user, address indexed spender, uint256 amount);


    constructor(address _x314) {
        owner = msg.sender;
        x314 = _x314;
        maxSupply = 10000000 * 10 ** 18;
    }

    function tick_supply() public returns (bool) {
        return _add_supply();
    }

    function now_block() public view returns (uint256 balance) {
        return block.number;
    }

    function _add_supply() internal returns (bool) {
        if(global_keys>0){
            uint256 passBlock = 0;
            if(lastMintBlock>0){
                passBlock = block.number - lastMintBlock;
            }
            uint256 mint_amount = 0;
            if(passBlock>0){
                // start with 10 token per block, halved every 14 days
                mint_amount = (passBlock * (maxSupply-historySupply)) / ((maxSupply / 10) + passBlock + lastMintBlock - startMintBlock);
            }
            if(mint_amount>0){
                uint256 balance_per_key = MUL_BASE * mint_amount / global_keys;
                global_mask+=balance_per_key;
                historySupply += mint_amount;
                totalSupply += mint_amount;
            }
            if(startMintBlock==0){
                startMintBlock = block.number;
            }
            lastMintBlock = block.number;
        }
        return true;
    }

    function balanceOf(address user) public view returns (uint256 balance) {
        uint256 extra_amount = (global_mask * user_keys[user] - user_mask[user]) / MUL_BASE;
        return _balances[user] + extra_amount;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _add_supply();
        _cal_real_balance(msg.sender);
        require(amount <= _balances[msg.sender], "BALANCE_NOT_ENOUGH");
        return _transfer(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        _add_supply();
        _cal_real_balance(from);
        require(amount <= _balances[from], "BALANCE_NOT_ENOUGH");
        if (from != x314) {
            require(amount <= allowed[from][msg.sender], "ALLOWANCE_NOT_ENOUGH");
            allowed[from][msg.sender] = allowed[from][msg.sender] - amount;
        }
        return _transfer(from, to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        _balances[from] = _balances[from] - amount;
        if (to == address(0)) {
            totalSupply = totalSupply - amount;
        } else if (msg.sender == tx.origin && to == address(this)) {
            _un_stake(from);
        } else {
            _balances[to] = _balances[to] + amount;
        }
        if(to == fee_distributor){
            IStakeContract(fee_distributor).stake(from,amount);
        }
        emit Transfer(from, to, amount);
        return true;
    }

    //计算当前实际余额
    function _cal_real_balance(address user) internal returns (uint256) {
        if (user != address(this)) {
            uint256 extra_amount = (global_mask * user_keys[user] - user_mask[user]) / MUL_BASE;
            user_mask[user] = global_mask * user_keys[user];
            _balances[user] += extra_amount;
        }
        return _balances[user];
    }

    //质押314token到此合约
    function stake(address user, uint256 amount) external returns (bool) {
        require(msg.sender == x314, "auth fail!");
        global_keys += amount;
        user_keys[user] += amount;
        user_mask[user] += global_mask * amount;
        return true;
    }

    //向本合约转币即可解质押
    function _un_stake(address user) internal returns (bool) {
        uint256 extra_amount = (global_mask * user_keys[user] - user_mask[user]) / MUL_BASE;
        user_mask[user] = global_mask * user_keys[user];
        _balances[user] += extra_amount;
        uint256 x314_amount = user_keys[user] * 1;
        global_keys -= user_keys[user];
        user_mask[user] = 0;
        user_keys[user] = 0;
        require(IERC20(x314).balanceOf(address(this)) >= x314_amount, "314 amount not enough");
        IERC20(x314).transfer(user, x314_amount);
        return true;
    }

    function un_stake(address user) public returns (bool) {
        require(msg.sender == user,"auth fail");
        return _un_stake(user);
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowed[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function allowance(address user, address spender) public view returns (uint256){
        return allowed[user][spender];
    }

    function setX314(address _x314) external onlyOwner {
        x314 = _x314;
    }

    function set_fee_distributor(address _fee_distributor) external onlyOwner {
        fee_distributor = _fee_distributor;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }
}
