// SPDX-License-Identifier: UNLICENSED 
pragma solidity ^0.8.25; 

import "./Castle.sol"; // Adjust the path if needed
import "./SolidusStaking.sol"; // Adjust the path if needed
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

address[] public eligibleCastles; 
SolidusStaking public stakingContract;
address public kingAddress; // Address to receive the King's share

uint256 public totalMintableSUS;  // Total SUS available for Kingdom-level minting
uint256 public totalBurnableSUS;   // Total SUS burnable at the 0.995 price
uint256 public lastLiquidationCheck; 
uint256 public liquidationCheckInterval = 10 * 60; // Example: Check every 10 min. 
uint256 public lastGiftTime; // Tracks the timestamp of the last Gift Time event
uint256 public lastAnnualDistribution; // Tracks when the last annual distribution was triggered
uint256 public giftTimeInterval = 60; // Example: 1 minute for testing
uint256 public annualDistributionInterval = 365 * 24 * 60 * 60; // 1 year in seconds


contract Kingdom is VRFConsumerBaseV2, KeeperCompatibleInterface { 
    VRFCoordinatorV2Interface COORDINATOR;
    // Your subscription ID, etc. (Chainlink setup required) ...

    uint256 lastGiftTime;
    uint256 giftTimeInterval = 60; // 1 minute for testing 
    address public kingAddress; 

    // ... (Constructor to initialize VRFCoordinatorV2Interface) ...

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        upkeepNeeded = (block.timestamp - lastGiftTime) > giftTimeInterval;
        // ... return upkeepNeeded;
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        // Ensure only Chainlink Keeper can call this
        if ((block.timestamp - lastGiftTime) > giftTimeInterval) {
            lastGiftTime = block.timestamp;
            requestRandomness(); 
        }
    }

    function requestRandomness() internal {
        COORDINATOR.requestRandomWords(/* ... Chainlink VRF parameters ... */);
    }

    function fulfillRandomWords(uint256,  uint256[] memory randomWords) internal override {
        uint256 randomness = randomWords[0];
        if (randomness % 1440 == 0) { // Simulating 1/1440 probability
            triggerGiftTime(); 
        } 
    }

   // Replace with placeholders for now
    address[] memory stakerAddresses = getStakerAddresses();
    uint256[] memory stakerAmounts = getStakerAmounts(); 
    address[] memory castleAddresses = getEligibleCastles();
    uint256[] memory castleAmounts = calculateCastleDistribution(distributionAmount);

    // Call giftTimeDistribution on Florint contract 
    Florint(florintAddress).giftTimeDistribution(distributionAmount, stakerAddresses, stakerAmounts, castleAddresses, castleAmounts); 
}

contract Kingdom { 

function calculateGCR() public view returns (uint256) {
    uint256 totalCollateral = calculateTotalCollateral(); // You likely already have or can easily implement this
    uint256 totalSusDebt = calculateTotalSusDebt();  // You'll need a function for this

    // Handle potential division by zero
    if (totalSusDebt == 0) {
        return type(uint256).max; // Or some very high value to represent an over-collateralized system 
    }

    // Calculate GCR (adjust decimals if needed)
    uint256 gcr = (totalCollateral * 1000) / totalSusDebt;  
    return gcr;
}

function calculateGiftTimeMintAmount() public view returns (uint256) {
    uint256 remainingSupply = MAX_SUPPLY - mintedSupply;
    uint256 annualMintAmount = remainingSupply * 10 / 100; // 10% of remaining supply
    uint256 giftTimeMintAmount = annualMintAmount / 365;
    return giftTimeMintAmount;
}

function triggerGiftTime() internal { 
    // 1. Calculate GCR (you already have this function)
    uint256 gcr = calculateGCR(); 

    // 2. Calculate Distribution Ratios 
    (uint256 stakerFraction, uint256 castleFraction) = calculateDistributionRatios(gcr);

    // 3. Calculate Gift Time Florint Amount (you already have this)
    uint256 giftTimeFlorint = calculateGiftTimeMintAmount();

/   / Calculate castle distribution
    (address[] memory castleAddresses, uint256[] memory castleAmounts) = calculateCastleDistribution(distributionAmount); // We'll rename this slightly

    // Distribute Florint to Castles
    distributeFlorint(distributionAmount); // Adjust amount as needed

    // 4. Gather distribution data
    address[] memory stakerAddresses = getStakerAddresses();
    uint256[] memory stakerAmounts = getStakerAmounts(); 
    address[] memory castleAddresses = getEligibleCastles(); 
    uint256[] memory castleAmounts = calculateCastleDistribution(distributionAmount); 

    // 5. Call Florint's giftTimeDistribution
    Florint(florintAddress).giftTimeDistribution(
        giftTimeFlorint, 
        stakerAddresses, 
        stakerAmounts, 
        castleAddresses, 
        castleAmounts
    )
    lastGiftTime = block.timestamp; // Update after Gift Time distribution;
} 
function calculateDistributionRatios(uint256 gcr) public view returns (uint256 stakerFraction, uint256 castleFraction) {
    uint256 phi = 1618 * 10**3; // Golden Ratio (adjust decimals as needed)

    if (gcr < (1300 * 10**3)) {
        gcr = 1300 * 10**3; // Minimum GCR
    } else if (gcr > (2718 * 10**3)) {
        gcr = 2718 * 10**3; // Approximate GCR based on 'e'
    }

    // Interpolation for stakers (50% at phi, 100% at e)
    stakerFraction = (gcr - phi) * 10**3 / (1418 * 10**3); 

    // Interpolation for Castles (50% at phi, 0% at 1.3)
    castleFraction = (1300 * 10**3 - gcr) * 10**3 / (318); 
}

function distributeFlorint(uint256 florintAmount) private { 
    // 1. Get eligible Castles (you can reuse getEligibleCastles)
    address[] memory eligibleCastles = getEligibleCastles(/* Threshold Ratio */);

    // 2. Calculate total excess collateral (reuse existing logic)
    uint256 totalExcessCollateral = calculateTotalExcessCollateral(eligibleCastles);

    // 3. Distribute Florint based on each Castle's share of the total excess collateral
    for (uint256 i = 0; i < eligibleCastles.length; i++) {
        address castleAddress = eligibleCastles[i];
        uint256 castleExcessCollateral = getCastleExcessCollateral(castleAddress);

        // Calculate the amount of Florint to distribute to this Castle
        uint256 florintAmountForCastle = (castleExcessCollateral * florintAmount) / totalExcessCollateral;

        // Trigger Florint transfer to the Castle 
        Florint(florintAddress).transfer(castleAddress, florintAmountForCastle); 

        // Note: You won't need the 'seigniorage' logic as Florint is not being minted here
    }
}

function calculateTotalCollateral() public view returns (uint256) {
    uint256 totalCollateral = 0;
    for (address castleAddress : castles) {
        CastleRecord storage record = castles[castleAddress];
        totalCollateral += record.weethCollateral;
    }
    return totalCollateral;
}

function calculateTotalSusDebt() public view returns (uint256) {
    uint256 totalSusDebt = 0;
    for (address castleAddress : castles) {
        CastleRecord storage record = castles[castleAddress];
        totalSusDebt += record.susDebt;
    }
    return totalSusDebt;
}
function calculateDistributionAmounts(uint256 giftTimeFlorint) public view returns (uint256 stakerShare, uint256 castleShare) {
    uint256 gcr = calculateGCR(); 

    // Ensure GCR is within the valid range (1.3 to e)
    if (gcr < 1300 / 1000) {
        gcr = 1300 / 1000; 
    } else if (gcr > 2718 / 1000) { // Approximation of 'e'
        gcr = 2718 / 1000;
    }

    // Define the Golden Ratio (phi) 
    uint256 phi = (1 + 5**0.5) / 2 * 1000; // Approximately 1618

    // Interpolation for stakers (50% at phi, 100% at e)
    uint256 stakerFraction = (gcr - phi) / (2718 / 1000 - phi); // Using 'e' and phi 

    // Interpolation for Castles (50% at phi, 0% at 1.3)
    uint256 castleFraction = (1300 / 1000 - gcr) / (phi - 1300 / 1000);  // Using phi

   // Adjust for the King's share (20% of giftTimeFlorint) 
    uint256 totalDistribution = giftTimeFlorint * 80 / 100; 
    stakerShare = totalDistribution * stakerFraction;
    castleShare = totalDistribution * castleFraction;
}
function getStakerAddresses() public view returns (address[] memory) {
    return stakingContract.stakerAddresses(); // Directly access the array
}

function getStakerAmounts() public view returns (uint256[] memory) {
    address[] memory addresses = getStakerAddresses();
    uint256[] memory amounts = new uint256[](addresses.length);

    for (uint256 i = 0; i < addresses.length; i++) {
        amounts[i] = stakingContract.stakedBalances(addresses[i]);
    }

    return amounts;
}
function checkForLiquidations() public {
    require(block.timestamp >= lastLiquidationCheck + liquidationCheckInterval, "Not time for liquidation check yet");
    lastLiquidationCheck = block.timestamp;

    // Iterate through Castles
    for (address castleAddress : castles) {
        CastleRecord storage record = castles[castleAddress];

        if (record.collateralizationRatio <= 1200 / 1000) {
            Castle(castleAddress).liquidateCastle();
        }
    }
}

function distributeToKnightlyCastles(uint256 collateralAmount, uint256 susDebt) private {
    // ... (Calculate totalSystemCollateral, targetKnightlyCollateral) ... 

    // ... (Populate castleDataArray) ... 

    // Sort castleDataArray by collateralization ratio (descending)
    for (uint256 i = 1; i < castleDataArray.length; i++) {
        // ... (Insertion Sort logic from above) ... 
    }

    // Select Knightly Castles
    address[] memory knightlyCastles;
    uint256 accumulatedCollateral = 0;
    for (uint256 i = 0; i < castleDataArray.length; i++) {
        accumulatedCollateral += castleDataArray[i].weethCollateral; 
        knightlyCastles.push(castleDataArray[i].castleAddress);

        if (accumulatedCollateral >= targetKnightlyCollateral) {
            if (accumulatedCollateral - castleDataArray[i].weethCollateral < targetKnightlyCollateral) {
                knightlyCastles.pop(); 
            }
            break; 
        }
    }

    // Distribute proportionally based on knightlyCastles' collateral
    for (uint256 i = 0; i < knightlyCastles.length; i++) {
        address castleAddress = knightlyCastles[i];
        CastleRecord storage record = castles[castleAddress];

        uint256 collateralShare = (record.weethCollateral * collateralAmount) / totalKnightlyCollateral;
        uint256 debtShare = (record.susDebt * susDebt) / totalKnightlyCollateral; // Requires susDebt tracking in Castle

        // Update collateral and debt in the Castle (implementation needed) 
        record.weethCollateral += collateralShare;
        record.susDebt += debtShare; 
    }
}


    // Data Structures
    struct CastleRecord {
        address castleAddress;      
        uint256 collateralizationRatio; 
    }

    mapping(address => CastleRecord) public castles; 

    // Variables
    IERC20 public weeth;  
    IERC20 public solidus;  

uint256 public minimumMintingAmount;  
uint256 public minimumBurningAmount;

    // Constructor
    constructor(address _weeth, address _solidus) {
        weeth = IERC20(_weeth);
        solidus = IERC20(_solidus);
        minimumMintingAmount = 10 * 10**18; // Example: 10 WEETH
        minimumBurningAmount = 10 * 10**18; // Example: 10 Solidus
        lastGiftTime = block.timestamp; 
        lastAnnualDistribution = block.timestamp;

         // Instantiate the Solidus staking contract
    stakingContract = new SolidusStaking(_solidus); // Pass your Solidus token address
    }

    // Minting Solidus 
    function mintSolidus(uint256 weethAmount) external {
        require(weethAmount >= minimumMintingAmount, "WEETH amount below minimum");
        // 1. Transfer WEETH from the user's wallet to the Kingdom contract
        weeth.transferFrom(msg.sender, address(this), weethAmount);

        // 2. Calculate the amount of Solidus to mint (weethAmount * 1000 / 1005)
        uint256 solidusAmount = weethAmount * 1000 / 1005; 

        // 3. Distribute minting across eligible Castles 
        distributeMinting(solidusAmount);

        // 4. Seigniorage distribution 
        distributeSeigniorage(solidusAmount); 

        // 5. Transfer minted Solidus to the user
        solidus.transfer(msg.sender, solidusAmount);
    }
function kingdomMint(uint256 mintAmount) public {
    // ... Require statements for valid amounts etc. ...

    // 1. Calculate total mintable SUS
    uint256 totalMintableSUS = calculateTotalMintableSUS();
    kingdomMintOfferPrice = 1005 * 10**18 / getLatestWETHPrice(); // Example for 1.005 offer 
    // 2. Create orderbook offer for totalMintableSUS (at 1.005 conversion rate) 
    // ... interact with your orderbook contract ...

    // 3. Safety check for large mints 
    if (mintAmount > totalMintableSUS * 80 / 100) { // Only check if mint is large
        for (address castleAddress : eligibleCastles) {
            require(Castle(castleAddress).collateralizationRatio() >= 1200 / 1000, "Minting would violate Castle's ratio");
        }
    }

    // 4. Trigger proportional minting based on totalMintableSUS
    // ... loop through eligibleCastles, calculate proportional SUS amounts ...
    // ... call the kingdomMint function on eligible Castle contracts ... 
}

// Helper function to calculate the total SUS that can be minted
function calculateTotalMintableSUS() private view returns (uint256) {
    uint256 totalMintable = 0;
    for (address castleAddress : eligibleCastles) {
        totalMintable += calculateCastleMintableSUS(castleAddress);
    }
    return totalMintable;
}

// Helper function (needs logic to determine how much a Castle can mint without dropping below 1.3 ratio)
function calculateCastleMintableSUS(address castleAddress) private view returns (uint256) {
    // ...  Your logic here ... 
}
function distributeMinting(uint256 solidusAmount) private { 
    // 1. Get eligible Castles
    address[] memory eligibleCastles = getEligibleCastles(/* Threshold Ratio */);
    function addEligibleCastle(address castleAddress) public {
    // ... (Potentially add onlyOwner or governance checks as needed)
    eligibleCastles.push(castleAddress);
}

    function removeEligibleCastle(address castleAddress) public {
    // ... (Potentially add onlyOwner or governance checks as needed)
    uint256 index = indexOf(castleAddress);
    require(index != type(uint256).max, "Castle not found"); 
    eligibleCastles[index] = eligibleCastles[eligibleCastles.length - 1];
    eligibleCastles.pop();
}

    // Helper function to find a Castle's index 
    indexOf(address castleAddress) private view returns (uint256) {
    for (uint256 i = 0; i < eligibleCastles.length; i++) {
        if (eligibleCastles[i] == castleAddress) {
            return i;
        }  
    }
    return type(uint256).max; 
}

    // 2. Calculate total excess collateral across the eligible Castles 
    uint256 totalExcessCollateral = calculateTotalExcessCollateral(eligibleCastles);

    // 3. Distribute minting based on each Castle's share of the total excess collateral
    for (uint256 i = 0; i < eligibleCastles.length; i++) {
        address castleAddress = eligibleCastles[i];
        uint256 castleExcessCollateral = getCastleExcessCollateral(castleAddress);

        // Calculate the amount of Solidus to be minted by this Castle
        uint256 mintAmountForCastle = (castleExcessCollateral * solidusAmount) / totalExcessCollateral;

        // Calculate Seigniorage
        uint256 seigniorageAmount = mintAmountForCastle * 5 / 1000;  
        uint256 amountToSendToCastle = mintAmountForCastle + seigniorageAmount;

        // Trigger minting in the Castle contract 
        weeth.transfer(castleAddress, amountToSendToCastle); // Transfer WEETH with seigniorage
        Castle(castleAddress).kingdomMint(mintAmountForCastle); 

        // Update collateralization state in the Castle contract and in the Kingdom's record
        // ... (code to update collateral and debt in the Castle)
        // ... (code to update the CastleRecord in the castles mapping)
    }
}
    // Burning Solidus
    function burnSolidus(uint256 solidusAmount) external {
    require(solidusAmount >= minimumBurningAmount, "Solidus amount below minimum");

    // 1. Transfer Solidus from the user's wallet to the Kingdom contract
    solidus.transferFrom(msg.sender, address(this), solidusAmount);

    // 2. Calculate the amount of WEETH to send to the user (solidusAmount * 995 / 1000)
    uint256 weethAmount = solidusAmount * 995 / 1000; 

    // Update the Kingdom's burnable SUS amount
    require(solidusAmount <= totalBurnableSUS, "Burn amount exceeds Kingdom bid"); // Use solidusAmount here 
    totalBurnableSUS -= solidusAmount;
    kingdomBurnBidPrice = 995 * 10**18 / getLatestWETHPrice(); // Example for 0.995 bid 

    // 3. Distribute the burning task proportionally across Castles based on their net worth
    distributeBurning(solidusAmount); 
    
    function distributeBurning(uint256 solidusAmount) private {
    uint256 totalSusDebt = calculateTotalSusDebt(); // You'll likely have this function already

    for (address castleAddress : castles) { // Loop over all Castles
        CastleRecord storage record = castles[castleAddress];

        // Proportional burn calculation
        uint256 burnAmountForCastle = (record.susDebt * solidusAmount) / totalSusDebt;

        // Attempt the burn, handle potential reverts 
        try Castle(castleAddress).kingdomBurn(burnAmountForCastle) {
            // Burn successful, no action needed
        } catch (Error error) {
            // Log the error and the Castle address for analysis
            console.log("Kingdom burn error:", error, castleAddress); 
        }

        // Trigger burning in the Castle contract
        Castle(castleAddress).kingdomBurn(burnAmountForCastle); 

    }
}

    // Ensure the collateralizationRatio in the castles mapping is also updated
    castles[castleAddress].collateralizationRatio =  Castle(castleAddress).collateralizationRatio(); // Assuming you have a getter / public accessor

        // 4. Distribute Seigniorage (if any rules apply)
        // ... potential seigniorage logic here

        // 5. Transfer WEETH from the Kingdom contract to the user
        weeth.transfer(msg.sender, weethAmount);
    }
} 
function getCastleExcessCollateral(address castleAddress) private view returns (uint256) {
    CastleRecord storage record = castles[castleAddress];

    // Calculate required collateral (example: minimum ratio is 1.2)
    uint256 requiredCollateral = record.susDebt * 1200 / 1000;

    // Ensure we don't underflow in case collateral is very low
    if (record.weethCollateral < requiredCollateral) {
        return 0; 
    }

    uint256 excessCollateral = record.weethCollateral - requiredCollateral;
    return excessCollateral;
}
function calculateCastleMintableSUS(address castleAddress) private view returns (uint256) {
    CastleRecord storage record = castles[castleAddress];
    uint256 totalCollateral = record.weethCollateral;
    uint256 susDebt = record.susDebt;

    // Ensure minting won't push the Castle below a 1.3 ratio
    if (totalCollateral < 13 * susDebt / 10) { 
        return 0; // Castle cannot mint without going below 1.3 ratio
    }

    // Calculate minting capacity (maintains 1.3 ratio)
    uint256 mintableSUS = (totalCollateral - 13 * susDebt / 10) / 3 / 10; // Adjust decimals if needed
    return mintableSUS;
}

function distributeMinting(uint256 solidusAmount) private { 
    // 1. Get eligible Castles
    address[] memory eligibleCastles = getEligibleCastles(/* Threshold Ratio */);
    function getEligibleCastles(uint256 thresholdRatio) private view returns (address[] memory) {
    address[] memory eligibleCastlesArray = new address[](castles.length); // Potentially optimize array size later
    uint256 numEligibleCastles = 0; 

    // Iterate through the castles mapping
    for (address castleAddress : castles) {
        CastleRecord storage record = castles[castleAddress];

        if (record.collateralizationRatio >= thresholdRatio) {
            eligibleCastlesArray[numEligibleCastles] = castleAddress;
            numEligibleCastles++;
        }
    }

    // Return the array of eligible Castle addresses
    return eligibleCastlesArray;
}
    // 2. Calculate total excess collateral across the eligible Castles 
    uint256 totalExcessCollateral = calculateTotalExcessCollateral(eligibleCastles);
function calculateTotalExcessCollateral(address[] memory castles) private view returns (uint256) {
    uint256 totalExcess = 0;

    for (uint256 i = 0; i < castles.length; i++) {
        address castleAddress = castles[i];
        uint256 castleExcessCollateral = getCastleExcessCollateral(castleAddress);
        totalExcess += castleExcessCollateral;    
    }

    return totalExcess;
}
    // 3. Distribute minting based on each Castle's share of the total excess collateral
    for (uint256 i = 0; i < eligibleCastles.length; i++) {
        address castleAddress = eligibleCastles[i];
        uint256 castleExcessCollateral = getCastleExcessCollateral(castleAddress);

        // Calculate the amount of Solidus to be minted by this Castle
        uint256 mintAmountForCastle = (castleExcessCollateral * solidusAmount) / totalExcessCollateral;

        // Trigger minting in the Castle contract 
        Castle(castleAddress).selfMint(mintAmountForCastle); 

        // Update collateralization state in the Castle contract and in the Kingdom's record
        // ... (code to update collateral and debt in the Castle)
        // ... (code to update the CastleRecord in the castles mapping)
    }
     
function addEligibleCastle(address castleAddress) public {
    // ... (Potentially add onlyOwner or governance checks as needed)
    eligibleCastles.push(castleAddress);
}

function removeEligibleCastle(address castleAddress) public {
    // ... (Potentially add onlyOwner or governance checks as needed)
    uint256 index = indexOf(castleAddress);
    require(index != type(uint256).max, "Castle not found"); 
    eligibleCastles[index] = eligibleCastles[eligibleCastles.length - 1];
    eligibleCastles.pop();
}

// Helper function to find a Castle's index 
function indexOf(address castleAddress) private view returns (uint256) {
    for (uint256 i = 0; i < eligibleCastles.length; i++) {
        if (eligibleCastles[i] == castleAddress) {
            return i;
        }  
    }
    return type(uint256).max; 
}

function updateTotalBurnableSUS() public { 
    // Logic to iterate through Castles and aggregate their susDebt 
    uint256 totalDebt = 0;
    for (address castleAddress : castles) {
        CastleRecord storage record = castles[castleAddress];
        totalDebt += record.susDebt; 
    }

    totalBurnableSUS = totalDebt; 
} 
function getStakerAddresses() public view returns (address[] memory) {
    // ... Logic to iterate through the stakedBalances mapping in SolidusStaking and return addresses with non-zero balances ...
}

function getStakerAmounts() public view returns (uint256[] memory) {
    // ... Logic to get the corresponding stakedAmounts for the addresses returned by getStakerAddresses ... 
} 
// Variables for minting offer
uint256 public totalMintableSUS;  
uint256 public kingdomMintOfferPrice; // WEETH price per SUS for the Kingdom's mint offer

// Variables for burning bid
uint256 public totalBurnableSUS;  
uint256 public kingdomBurnBidPrice;  // WEETH price per SUS for the Kingdom's burn bid

}

