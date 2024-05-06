contract SolidusStaking {
    IERC20 public solidus; 
    mapping(address => uint256) public stakedBalances; 
    address[] public stakerAddresses; // Auxiliary array


    // Constructor
    constructor(address _solidus) {
        solidus = IERC20(_solidus);
    }

    function stake(uint256 amount) public {
        require(amount > 0, "Cannot stake zero amount");
        solidus.transferFrom(msg.sender, address(this), amount);
        stakedBalances[msg.sender] += amount;
         // Add to stakerAddresses if not already present
        if (!isStaker(msg.sender)) { 
            stakerAddresses.push(msg.sender);
        }
    }

    function unstake(uint256 amount) public {
        require(stakedBalances[msg.sender] >= amount, "Insufficient staked balance");
        stakedBalances[msg.sender] -= amount;
        solidus.transfer(msg.sender, amount);
         // Remove from stakerAddresses if balance is now zero
        if (stakedBalances[msg.sender] == 0) { 
            removeStaker(msg.sender);
        }
    }
    // Helper functions to check and remove from stakerAddresses
    function isStaker(address _address) private view returns(bool) {
        for (uint256 i = 0; i < stakerAddresses.length; i++) {
            if (stakerAddresses[i] == _address) {
                return true;
            }
        }
        return false;
    }

    function removeStaker(address _address) private {
        for (uint256 i = 0; i < stakerAddresses.length; i++) {
            if (stakerAddresses[i] == _address) {
                stakerAddresses[i] = stakerAddresses[stakerAddresses.length - 1];
                stakerAddresses.pop();
                break;
            }
        }
    }
}

