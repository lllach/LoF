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

    // Function to take out a Templar stabilization loan
    function takeTemplarLoan(uint256 susAmount) external {
        uint256 requiredCollateral = kingdomContract.wethPriceFor150Usd() * susAmount / 10**18; // 1.5 collateral ratio (adjust decimals if needed)
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

    // Function to repay a Templar stabilization loan
    function repayTemplarLoan() external {
        TemplarLoan storage loan = loans[msg.sender];
        require(loan.active, "No active loan found");

        // Calculate the SUS repayment amount (squared repayment logic)
        uint256 susPrice = orderBook.getAverageSusPrice();
        uint256 susRepaymentAmount = max(loan.amountSUS, (loan.amountSUS * 1030) / 1000); // 1.03 is the SUS/USD price, adjust decimals if needed
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

        emit TemplarHit(msg.sender, amountToSell);
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
