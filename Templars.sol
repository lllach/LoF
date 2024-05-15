// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Kingdom.sol";
import "./OrderBook.sol";
import "./Solidus.sol";

contract Templars {
    IERC20 public weth;
    Solidus public solidus;  
    Kingdom public kingdomContract;
    OrderBook public orderBook;
    uint256 public averageSusRepaymentPrice;

    struct TemplarLoan {
        uint256 amountSUS;       // Amount of SUS borrowed
        uint256 amountCollateral; // Amount of WEETH provided as collateral
        uint256 loanStartTime;    // Timestamp when the loan was initiated
        bool active;             // Flag to indicate if the loan is still active
    }

    mapping(address => TemplarLoan) public loans;
    address public kingCustody;  

    event TemplarLoanCreated(address indexed templars, uint256 amountSUS, uint256 amountCollateral);
    event TemplarLoanRepaid(address indexed templars, uint256 amountSUS, uint256 amountCollateral);
    event TemplarHit(address indexed templars, uint256 susAmount);

    constructor(
        address _weth, 
        address _solidus,
        address _kingdomContract,
        address _orderBook,
        address _kingCustody
    ) {
        weth = IERC20(_weth);
        solidus = Solidus(_solidus);
        kingdomContract = Kingdom(_kingdomContract);
        orderBook = OrderBook(_orderBook);
        kingCustody = _kingCustody;
    }

function prepareTemplarHit(uint256 susAmount) external {
  require(susAmount > 0, "SUS amount must be greater than zero");
  // ... (other validations)

  // Calculate required collateral with 1.5x ratio
  uint256 requiredCollateral = susAmount * findQualifyingBid(susAmount).price * 3 / (2 * 10**18);

  // Ensure user has enough WEETH for collateral
  require(weth.balanceOf(msg.sender) >= requiredCollateral, "Insufficient WEETH for collateral");

  Bid memory qualifyingBid = findQualifyingBid(susAmount);
  require(qualifyingBid.active, "No qualifying bid found");

  preparedTemplarHits[msg.sender] = TemplarHitPreparation({susAmount: susAmount, bid: qualifyingBid});
}

    // Function to take out a Templar stabilization loan
    function takeTemplarLoan(uint256 susAmount) external {
       // Find a qualifying bid
        Bid memory qualifyingBid = findQualifyingBid(susAmount);
        require(qualifyingBid.active, "No qualifying bid found");
        // Calculate required collateral with 1.5x ratio
        uint256 requiredCollateral = susAmount * qualifyingBid.price * 3 / (2 * 10**18); // Adjust decimals if needed
        require(
            weth.transferFrom(msg.sender, kingCustody, requiredCollateral),
            "WEETH transfer for collateral failed"
        );

        kingdomContract.stabilizationMint(susAmount);

        loans[msg.sender] = TemplarLoan({
            amountSUS: susAmount,
            amountCollateral: requiredCollateral,
            loanStartTime: block.timestamp,
            active: true
        });

        emit TemplarLoanCreated(msg.sender, susAmount, requiredCollateral);
    }
// Function to calculate Templar loan repayment amounts (called by Keeper)
  function calculateTemplarRepayment() external {
    // Loop through active loans
    for (address borrower in activeLoanBorrowers) {
      TemplarLoan storage loan = loans[borrower];
      if (loan.active) {
        // Calculate timeframe for average price (considering 18 hours after "Templar hit")
        uint256 timeframeStart = loan.loanStartTime + 18 hours;
        uint256 timeframeEnd = timeframeStart + 6 hours; // Assuming 6 hours for price calculation
        
        // Call OrderBook function to get average price
        uint256 averageSusPrice = orderBook.getAveragePriceOfLowestOffersForTemplar(timeframeStart, timeframeEnd);
        
        // Update storage variable with average price for this loan's repayment
        averageSusRepaymentPrice = averageSusPrice; 
      }
    }
  }

    // Function to repay a Templar stabilization loan
    function repayTemplarLoan() external {
        TemplarLoan storage loan = loans[msg.sender];
        require(loan.active, "No active loan found");

        // Calculate the SUS repayment amount (squared repayment logic)
       // Retrieve the average SUS price for repayment (calculated by Keeper)
        uint256 averageSusUsdRate = getAverageSusRepaymentPrice();  // Call a new function to retrieve the price
        // Calculate the SUS repayment amount based on the average price
        uint256 susRepaymentAmount = loan.amountSUS * averageSusUsdRate / (10**18); // Adjust decimals if needed
        solidus.transferFrom(msg.sender, address(kingdomContract), susRepaymentAmount);
        kingdomContract.stabilizationBurn(loan.amountSUS); // Burn original loan amount

        // Send extra SUS to the King's Stabilization Fund
        uint256 kingFundAmount = susRepaymentAmount - loan.amountSUS;
        solidus.transferFrom(msg.sender, kingCustody, kingFundAmount);

        weth.transfer(msg.sender, loan.amountCollateral); // Return collateral
        loan.active = false; // Mark the loan as repaid

        emit TemplarLoanRepaid(msg.sender, loan.amountSUS, loan.amountCollateral);
    }
  
    // Function to perform a Templar Hit on a bid
    function templarHit(uint256 bidId) external {
        TemplarLoan storage loan = loans[msg.sender];
        require(loan.active, "No active loan found");

        Bid memory bid = orderBook.bids(bidId);
        require(bid.active, "Bid is not active");

        uint256 wethEquivalentOf103Usd = kingdomContract.wethPriceFor103Usd();
        require(bid.price >= wethEquivalentOf103Usd, "Bid price is below the Templar Hit threshold");

        uint256 amountToSell = min(bid.amount, loan.amountSUS); 

        // Execute the trade
        orderBook.executeMatch(bid.bidder, msg.sender, amountToSell, bid.price); 

        // Update loan amount (remaining SUS to be repaid)
        loan.amountSUS -= amountToSell; 

        loan.loanStartTime = block.timestamp; // Record "Templar hit" timestamp
  
        emit TemplarHit(msg.sender, amountToSell);
    }

    function executeTemplarHit() external {
  TemplarHitPreparation storage hit = preparedTemplarHits[msg.sender];
  require(hit.susAmount > 0, "No prepared Templar hit found");

  // Execute the trade using hit details (similar logic to templarHit)
  templarHit(hit.bid.id, hit.susAmount);

  // Remove prepared hit entry after successful execution
  delete preparedTemplarHits[msg.sender];
}

    // Helper function to get the maximum of two values
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    // Helper function to get the minimum of two values
    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x <= y ? x : y;
    }
}
