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

contract erc314 {
    address public owner;
    address public stoken;
    address public fee_distributor;

    string public name = "safe314";
    uint256 public decimals = 18;
    string public symbol = "SAFE314";
    uint256 public totalSupply;

    uint256 public virtual_eth;
    bool public trading_enable;
    uint256 public start_time;
    uint256 public max_wallet;
    uint256 sell_fly_rate = 100; //1%

    uint256 buy_fee = 400; //4%
    uint256 buy_burn_fee = 100; //1%

    uint256 sell_fee = 500; //5%
    uint256 sell_burn_fee = 1500; //15%

    uint256 bot_transfer_rate = 9500; //95%


    mapping(address => uint256) _balances;

    mapping(address => uint256) private _lastTxTime;
    mapping(address => uint32) private _lastTransaction;

    mapping(address => mapping(address => uint256)) internal allowed;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed user, address indexed spender, uint256 amount);
    event Swap(address indexed sender, uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out);

    constructor(uint256 _virtual_eth, address _stoken, uint256 _start_time) {
        owner = msg.sender;
        totalSupply = 21000000 * 10 ** 18;
        _balances[address(this)] = totalSupply;
        max_wallet = totalSupply / 20;
        trading_enable = false;
        virtual_eth = _virtual_eth;
        stoken = _stoken;
        fee_distributor = msg.sender;
        start_time = _start_time;
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
            _transfer(msg.sender, to, amount);
            if (msg.sender == tx.origin && to == stoken) {
                IStakeContract(stoken).stake(msg.sender, amount);
            }
            return true;
        }
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
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

    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        require(to != fee_distributor, "prevent loss");
        if (to != address(0)) {
            //prevent bot
            require(_lastTransaction[msg.sender] != block.number, "You can't make two transactions in the same block");
            _lastTransaction[msg.sender] = uint32(block.number);
            require(block.timestamp >= _lastTxTime[msg.sender] + 60, "Sender must wait for cooldown");
            _lastTxTime[msg.sender] = block.timestamp;
        }

        _balances[from] = _balances[from] - amount;
        if (to == address(0)) {
            //burn
            totalSupply = totalSupply - amount;
        } else {
            uint256 real_to_amount = amount;
            if(msg.sender != tx.origin){
                real_to_amount = (amount / 10000) * bot_transfer_rate;
            }
            _balances[to] = _balances[to] + real_to_amount;
        }
        require(_balances[to]<max_wallet,"max wallet exceeded");
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

    function getReserves() public view returns (uint256, uint256) {
        return (virtual_eth + address(this).balance, _balances[address(this)]);
    }

    function getAmountOut(uint256 value, bool _buy) public view returns (uint256){
        (uint256 reserveETH, uint256 reserveToken) = getReserves();
        if (_buy) {
            return (value * reserveToken) / (reserveETH + value);
        } else {
            return (value * reserveETH) / (reserveToken + value);
        }
    }

    function buy() internal {
        require(trading_enable && block.timestamp > start_time, "Trading not enable");
        uint256 share_amount = (msg.value / 10000) * buy_fee;
        uint256 swap_amount = msg.value - share_amount;
        uint256 token_amount = (swap_amount * _balances[address(this)]) / (address(this).balance + virtual_eth - share_amount);

        uint256 burn_token_amount = (token_amount / 10000) * buy_burn_fee;
        token_amount -= burn_token_amount;
        _transfer(address(this), msg.sender, token_amount);
        _transfer(address(this), address(0), burn_token_amount);
        safeTransferETH(fee_distributor, share_amount);
        emit Swap(msg.sender, msg.value, 0, 0, token_amount);
    }

    function sell(address user, uint256 sell_amount) internal {
        require(trading_enable && block.timestamp > start_time, "Trading not enable");
        uint256 burn_amount = (sell_amount / 10000) * sell_burn_fee;
        if (stoken != address(0)) {
            //caculate hedging token amount
            IERC20 ercStoken = IERC20(stoken);
            uint256 bal_stoken = ercStoken.balanceOf(user);
            if (bal_stoken >= burn_amount) {
                burn_amount = 0;
                ercStoken.transferFrom(user, address(this), burn_amount);
            } else if (bal_stoken > 0) {
                burn_amount = burn_amount - bal_stoken;
                ercStoken.transferFrom(user, address(this), bal_stoken);
            }
        }
        uint256 swap_amount = sell_amount - burn_amount;
        uint256 ethAmount = (swap_amount * (address(this).balance + virtual_eth)) / (_balances[address(this)] + swap_amount);

        require(ethAmount > 0, "Sell amount too low");
        require(address(this).balance >= ethAmount, "Insufficient ETH in reserves");
        _transfer(user, address(this), swap_amount);
        if (burn_amount > 0) {
            _transfer(user, address(0), burn_amount);
        }
        //fly token price
        _transfer(address(this), address(0), (sell_amount / 10000) * sell_fly_rate);
        uint256 share_amount = (ethAmount / 10000) * sell_fee;
        uint256 user_amount = ethAmount - share_amount;
        if (share_amount > 0) {
            safeTransferETH(fee_distributor, share_amount);
        }
        if (user_amount > 0) {
            payable(user).transfer(user_amount);
        }
        emit Swap(msg.sender, 0, sell_amount, ethAmount, 0);
    }

    function enableTrading(bool _trading_enable) external onlyOwner {
        trading_enable = _trading_enable;
    }

    function setStoken(address _stoken) external onlyOwner {
        stoken = _stoken;
    }

    function set_fee_distributor(address _fee_distributor) external onlyOwner {
        fee_distributor = _fee_distributor;
    }

    function set_fee(
        uint256 _buy_fee,
        uint256 _buy_burn_fee,
        uint256 _sell_fee,
        uint256 _sell_burn_fee,
        uint256 _sell_fly_rate,
        uint256 _bot_transfer_rate
    ) external onlyOwner {
        buy_fee = _buy_fee;
        buy_burn_fee = _buy_burn_fee;
        sell_fee = _sell_fee;
        sell_burn_fee = _sell_burn_fee;
        sell_fly_rate = _sell_fly_rate;
        bot_transfer_rate = _bot_transfer_rate;
    }

    receive() external payable {
        buy();
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success,) = to.call{value : value}(new bytes(0));
        require(success, "TransferHelper: ETH_TRANSFER_FAILED");
    }

    function timestamp() public view returns (uint256) {
        return block.timestamp;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

}
