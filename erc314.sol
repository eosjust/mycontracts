// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// File: contracts/lib/InitializableOwnable.sol

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address user) external view returns (uint256 balance);

    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract p314 {
    address public owner;
    address public stoken;
    address public fee_distributor;

    string public name = "p314";
    uint256 public decimals = 18;
    string public symbol = "P314";
    uint256 public totalSupply;

    uint256 public virtual_eth;
    bool public trading_enable;
    uint256 public max_transfer;

    uint256 buy_fee = 500; //5%
    uint256 buy_burn_fee = 300; //3%

    uint256 sell_fee = 1500; //15%
    uint256 sell_burn_fee = 500;//5%

    mapping(address => uint256) _balances;

    mapping(address => uint256) private _lastTxTime;
    mapping(address => uint32) private _lastTransaction;

    mapping(address => mapping(address => uint256)) internal allowed;
    mapping(address => address) public inviter;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(
        address indexed user,
        address indexed spender,
        uint256 amount
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out
    );

    constructor(uint256 _virtual_eth, address _stoken) {
        owner = msg.sender;
        totalSupply = 21000000 * 10**18;
        max_transfer = totalSupply / 100;
        trading_enable = false;
        virtual_eth = _virtual_eth;
        stoken = _stoken;
        _balances[msg.sender] = (totalSupply * 20) / 100;
        uint256 liquidityAmount = totalSupply - _balances[msg.sender];
        _balances[address(this)] = liquidityAmount;
    }

    function balanceOf(address user) public view returns (uint256 balance) {
        return _balances[user];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(amount <= _balances[msg.sender], "BALANCE_NOT_ENOUGH");
        if (to == address(this)) {
            sell(msg.sender, amount);
            return true;
        } else {
            return _transfer(msg.sender, to, amount);
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        require(amount <= _balances[from], "BALANCE_NOT_ENOUGH");
        require(amount <= allowed[from][msg.sender], "ALLOWANCE_NOT_ENOUGH");
        allowed[from][msg.sender] = allowed[from][msg.sender] - amount;
        if (to == address(this)) {
            sell(from, amount);
            return true;
        } else {
            return _transfer(from, to, amount);
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        if(to != address(0)){
            //防夹子
            require(
                _lastTransaction[msg.sender] != block.number,
                "You can't make two transactions in the same block"
            );
            _lastTransaction[msg.sender] = uint32(block.number);

            require(
                block.timestamp >= _lastTxTime[msg.sender] + 60,
                "Sender must wait for cooldown"
            );
            _lastTxTime[msg.sender] = block.timestamp;
        }

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

    function allowance(address user, address spender)
    public
    view
    returns (uint256)
    {
        return allowed[user][spender];
    }

    function getReserves() public view returns (uint256, uint256) {
        return (virtual_eth + address(this).balance, _balances[address(this)]);
    }

    function getAmountOut(uint256 value, bool _buy)
    public
    view
    returns (uint256)
    {
        (uint256 reserveETH, uint256 reserveToken) = getReserves();

        if (_buy) {
            return (value * reserveToken) / (reserveETH + value);
        } else {
            return (value * reserveETH) / (reserveToken + value);
        }
    }

    function buy() internal {
        require(trading_enable, "Trading not enable");
        uint256 share_amount = (msg.value / 10000) * buy_fee;
        uint256 swap_amount = msg.value - share_amount;
        uint256 token_amount = (swap_amount * _balances[address(this)]) /
        (address(this).balance + virtual_eth - share_amount);

        if (virtual_eth > 0 && share_amount > 0) {
            //补充虚拟底池
            uint256 add_virtual = share_amount / 2;
            if (virtual_eth < add_virtual) {
                add_virtual = virtual_eth;
            }
            virtual_eth -= add_virtual;
            share_amount -= add_virtual;
        }
        uint256 burn_token_amount = (token_amount / 10000) * buy_burn_fee;
        token_amount -= burn_token_amount;
        _transfer(address(this), msg.sender, token_amount);
        payable(fee_distributor).transfer(share_amount);
        emit Swap(msg.sender, msg.value, 0, 0, token_amount);
    }

    function sell(address user, uint256 sell_amount) internal {
        require(trading_enable, "Trading not enable");
        uint256 burn_amount = (sell_amount / 10000) * sell_fee;
        if (stoken != address(0)) {
            //计算抵消量
            IERC20 ercStoken = IERC20(stoken);
            uint256 bal_stoken = ercStoken.balanceOf(user);
            if (bal_stoken >= burn_amount) {
                burn_amount = 0;
                ercStoken.transferFrom(user, address(0), burn_amount);
            } else if (bal_stoken > 0) {
                burn_amount = burn_amount - bal_stoken;
                ercStoken.transferFrom(user, address(0), bal_stoken);
            }
        }
        uint256 swap_amount = sell_amount - burn_amount;
        uint256 ethAmount = (swap_amount *
        (address(this).balance) +
        virtual_eth) / (_balances[address(this)] + swap_amount);
        require(ethAmount > 0, "Sell amount too low");
        require(
            address(this).balance >= ethAmount,
            "Insufficient ETH in reserves"
        );
        payable(user).transfer(ethAmount);

        _transfer(user, address(this), swap_amount);
        _transfer(user, address(0), burn_amount);
        emit Swap(msg.sender, 0, sell_amount, ethAmount, 0);
    }

    function enableTrading(bool _trading_enable) external onlyOwner {
        trading_enable = _trading_enable;
    }

    function setStoken(address _stoken) external onlyOwner {
        stoken = _stoken;
    }

    receive() external payable {
        buy();
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }
}
