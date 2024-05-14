// SPDX-License-Identifier: UNLICENSED 
pragma solidity ^0.8.25; // Specify Solidity version

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./Kingdom.sol"; // Import the Kingdom contract


contract Castle {
    // Data Structures
    address public owner; 
    IERC20 public weeth; // Declare Interface for WEETH
    uint256 public weethCollateral; 
    uint256 public susDebt;
    string public title; 
    bool public knightlyStatus;
    enum Status { Active, Dormant, Liquidated } // Add an Enum for Castle states
    Status public status; 
    uint256 public collateralizationRatio; // Add collateralizationRatio

    // Constructor (when building a castle)
    constructor(address _weeth, uint256 initialCollateral, address _kingdomContract, address _solidusContract) {
        owner = msg.sender; 
        weeth = IERC20(_weeth); 
        weethCollateral = initialCollateral;
        susDebt = 0; 
        title = "Humble Abode"; 
        status = Status.Active; // Initialize the status to Active
        kingdomContract = _kingdomContract; // Store the Kingdom contract address
        ethPriceFeed = AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612); // Replace 0xABC... with the actual Aggregator address on your testnet
         // Automatic approval for Kingdom contract to burn/mint Solidus
    Solidus(_solidusContract).approve(_kingdomContract, type(uint256).max);
    }

    function depositCollateral() public payable {
        require(msg.sender == owner, "Only the owner can deposit collateral");
        require(weth.transferFrom(msg.sender, address(this), amount), "WEETH transfer failed");
        weethCollateral += msg.value; 
    }

      Solidity
function withdrawCollateral(uint256 amount) public {
    require(msg.sender == owner, "Only the owner can withdraw collateral");

    uint256 currentWETHPrice = Kingdom(kingdomContract).getLatestWETHPrice();

    // 1. Check if enough collateral remains after withdrawal (in WEETH)
    uint256 wethCollateralAfterWithdrawal = weethCollateral - amount;
    require(wethCollateralAfterWithdrawal >= 5 * 10**18, "Insufficient collateral after withdrawal"); 

    // 2. Calculate current collateralization ratio (in SUS terms, using current price)
    uint256 currentCollateralValue = (weethCollateral * currentWETHPrice) / 10**8; // Assuming 8 decimals for WEETH
    uint256 currentCollateralRatio = (currentCollateralValue * 1000) / susDebt;  // 1000 for 3 decimal places

    // 3. Calculate new collateralization ratio after withdrawal (in SUS terms)
    uint256 newCollateralValue = (wethCollateralAfterWithdrawal * currentWETHPrice) / 10**8;
    uint256 newCollateralRatio = (newCollateralValue * 1000) / susDebt;  

    // 4. Ensure new collateralization ratio is above the minimum
    require(newCollateralRatio >= 1200, "Withdrawal would violate collateralization ratio");  // Assuming 120% minimum ratio

    // 5. Execute the withdrawal
    weethCollateral = wethCollateralAfterWithdrawal; // Update collateral
    weth.transfer(msg.sender, amount);
}


   function selfMint(uint256 amount) public {
      require(msg.sender == owner, "Only the owner can self-mint Solidus");

      // Fetch the latest WETH price from the Kingdom contract
      uint256 currentWEETHPrice = Kingdom(kingdomContract).getLatestWETHPrice();

      uint256 susAmount = (amount * 10**18) / 1005;
      uint256 weethAmount = (susAmount * 1000) / currentWEETHPrice;

      require(
          (weethCollateral + weethAmount) * currentWEETHPrice >= (susDebt + susAmount) * 1200,
          "Minting would violate collateralization ratio"
      );

      // Minting logic
      weth.transferFrom(msg.sender, address(this), weethAmount);
      Solidus(solidusContract).mint(address(this), susAmount);
      weethCollateral += weethAmount;
      susDebt += susAmount;
       //Update the collateralization ratio in the Kingdom contract
      Kingdom(kingdomContract).updateCastleState(address(this), weethCollateral, susDebt); //add this line
  }

     function selfBurn(uint256 amount) public {
      require(msg.sender == owner, "Only the owner can self-burn Solidus");

      // Fetch the latest WETH price from the Kingdom contract
      uint256 currentWEETHPrice = Kingdom(kingdomContract).getLatestWETHPrice();

      uint256 weethAmount = amount * 995 / (1000 * currentWEETHPrice); // Calculate WEETH amount to receive

      require(susDebt >= amount, "Insufficient SUS debt"); // Ensure enough SUS debt to burn
      require(weethCollateral >= weethAmount, "Insufficient WEETH collateral to cover burn"); // Ensure enough WEETH collateral
    
      // Burning logic
      solidus.transferFrom(msg.sender, address(this), amount);
      Solidus(solidusContract).selfBurn(address(this), amount);
      weth.transfer(msg.sender, weethAmount);
      weethCollateral -= weethAmount; // Reduce the collateral
      susDebt -= amount;
  }

function kingdomMint(uint256 amount) external {
    require(msg.sender == kingdomContract, "Only the Kingdom contract can call this function");
    // ... Logic to mint Solidus (likely via Solidus.sol interaction)
    require(
        Solidus(solidusContract).mint(address(this), amount),
        "Solidus minting failed"
      );
    // Update collateralization state 
    weethCollateral += amount * 1000 / 1005; // Example, adjust based on how Kingdom sends WEETH
    susDebt += amount; 
    kingdomContract.updateCastleState(address(this), weethCollateral, susDebt);
    emit CastleMintedSUS(address(this), amount);
}
function kingdomBurn(uint256 amount) external {
    require(msg.sender == kingdomContract, "Only the Kingdom contract can call this function");

    // Ensure sufficient WEETH collateral (with alarm)
    if (weethCollateral < amount) {
        emit CastleApproachingLiquidation(address(this)); // Emit an event 
        return;  // Skip the burn for this Castle
        // Update collateralization state in Kingdom contract
    kingdomContract.updateCastleState(address(this), weethCollateral, susDebt);
    }

    // Burn Solidus tokens 
   Solidus(solidusContract).burn(address(this), amount); 

    // Update collateralization state
    susDebt -= amount; // Reduce the SUS debt
    weethCollateral -= amount; // Reduce WEETH collateral proportionally 

    //Update the collateralization ratio in the Kingdom contract
      Kingdom(kingdomContract).updateCastleState(address(this), weethCollateral, susDebt); //add this line
    emit CastleBurnedSUS(address(this), amount);
}


function reduceSusDebt(uint256 amount) external {
    require(msg.sender == kingdomContract, "Only the Kingdom contract can call this function");
    susDebt -= amount;
}

function reduceCollateral(uint256 amount) external {
    require(msg.sender == kingdomContract, "Only the Kingdom contract can call this function");
    weethCollateral -= amount;
}

function updateKnightlyStatus(uint256 newKnightlyCastleThreshold) public {
    require(msg.sender == kingdomContract, "Only the Kingdom contract can call this function");
    uint256 currentWETHPrice = Kingdom(kingdomContract).getLatestWETHPrice();
    uint256 weethCollateralValue = weethCollateral * currentWETHPrice / 10 ** 8; // Adjust decimals
    if (weethCollateralValue >= newKnightlyCastleThreshold) {
      knightlyStatus = true;
    } else {
      knightlyStatus = false;
    }
}
function liquidateCastle() external { 
    require(collateralizationRatio <= 1200 / 1000, "Castle not eligible for liquidation"); 

    // 1. Calculate net worth 
    uint256 netWorth = weethCollateral - susDebt;

    // 2. Send 90% to Lord
    uint256 amountForLord = netWorth * 90 / 100; 
    address payable lordAddress = payable(owner); 
    lordAddress.transfer(amountForLord); 

    // 3. Send 5% to Florint holders
    uint256 amountForFlorintHolders = netWorth * 5 / 100;

    // Distribute to Florint stakers (logic in the Kingdom contract)
    kingdomContract.distributeToFlorintStakers(amountForFlorintHolders);

    // 4. Distribute remaining assets to Knightly Castles 
    uint256 remainingCollateral = weethCollateral - amountForLord - amountForFlorintHolders; 
    uint256 remainingDebt = susDebt;
    kingdomContract.distributeToKnightlyCastles(remainingCollateral, remainingDebt);

    // 5. Mark Castle as liquidated 
    status = Status.Liquidated; 

    // Emit events for transparency
    emit CastleLiquidated(address(this), amountForLord, amountForFlorintHolders); 
}

// Event for liquidation
event CastleLiquidated(address indexed castleAddress, uint256 lordAmount, uint256 florintHoldersAmount);
event CastleApproachingLiquidation(address indexed castleAddress);

// Events for Kingdom Mint and Burn
  event CastleMintedSUS(address indexed castleAddress, uint256 amount);
  event CastleBurnedSUS(address indexed castleAddress, uint256 amount);

// Functions to increase WEETH collateral and SUS debt
    // (Only the Kingdom contract can call these)
    function increaseCollateral(uint256 amount) external {
        require(msg.sender == address(kingdomContract), "Only the Kingdom can increase collateral");
        weethCollateral += amount;
        updateCollateralizationRatio(); // Update after change
    }

    function increaseSusDebt(uint256 amount) external {
        require(msg.sender == address(kingdomContract), "Only the Kingdom can increase SUS debt");
        susDebt += amount;
        updateCollateralizationRatio(); // Update after change
    }
}
