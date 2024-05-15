// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Castle.sol";
import "./Kingdom.sol";
mapping(uint256 => OfferPrice) public historicalOfferPrices;

interface IOrderBook {
    function createBid(uint256 price, uint256 amount) external;
    function createOffer(uint256 price, uint256 amount) external;
    function cancelBid(uint256 orderId) external;
    function cancelOffer(uint256 orderId) external;
    function matchOrders() external;
    function initializeKingdomBid(uint256 totalSusCirculation) external;
    function updateKingdomOffer() external;
    function getKingdomOfferAmount() external view returns (uint256);
}

contract OrderBook is IOrderBook {
    struct Bid {
        uint256 id;
        uint256 price; // Price in USD 18 decimals
        uint256 amount;
        address bidder;
        bool active;
        uint256 expirationTime; // Add expiration time
    }

// Function to validate bid price against lowest offer
function validateBidPrice(uint256 price) internal view returns (bool) {
  uint256 lowestOfferPrice = getLowestOfferPrice();
  return price <= lowestOfferPrice || lowestOfferPrice == 0;
}

}
    struct Offer {
        uint256 id;
        uint256 price;  // Price in USD 18 decimals
        uint256 amount;
        address seller;
        bool active;
        uint256 expirationTime; // Add expiration time
    }

    struct OfferPrice {
  uint256 price;
  uint256 timestamp;
}

// Function to validate offer price against highest bid
function validateOfferPrice(uint256 price) internal view returns (bool) {
  uint256 highestBidPrice = getHighestBidPrice();
  return price >= highestBidPrice || highestBidPrice == 0;

    mapping(uint256 => Bid) public bids;
    mapping(uint256 => Offer) public offers;

    uint256[] public bidIds;
    uint256[] public offerIds;

    uint256 public nextBidId = 1;
    uint256 public nextOfferId = 1;

    IERC20 public weeth;
    IERC20 public solidus;
    Kingdom public kingdomContract;

    // Kingdom's permanent bid and offer variables
    Bid public kingdomBid;
    uint256 public kingdomOfferAmount;

    constructor(
        address _weth, 
        address _solidus, 
        address _kingdomContract
        uint256 _expirationPeriod 
    ) {
        weth = IERC20(_weth);
        solidus = IERC20(_solidus);
        kingdomContract = Kingdom(_kingdomContract);
        expirationPeriod = _expirationPeriod;
    }
    
    uint256 public expirationPeriod; // Default expiration period (e.g., 24 hours in seconds)

    // -- Events for Order Creation/Cancellation --

    event BidCreated(uint256 orderId, uint256 price, uint256 amount, address bidder);
    event OfferCreated(uint256 orderId, uint256 price, uint256 amount, address seller);
    event BidCancelled(uint256 orderId);
    event OfferCancelled(uint256 orderId);

    // -- Bid/Offer Creation and Cancellation Logic --
function createBid(uint256 price, uint256 amount) external override {
    require(price > 0, "Price must be greater than zero");
    require(amount > 0, "Amount must be greater than zero");
    require(validateBidPrice(price), "Bid price cannot exceed lowest offer");

    require(
        weth.transferFrom(msg.sender, address(this), price * amount),
        "WEETH transfer failed"
    );

    // Set expiration time (assuming `expirationPeriod` is in seconds)
    uint256 expirationTime = block.timestamp + expirationPeriod;

    bids[nextBidId] = Bid({
        id: nextBidId,
        price: price,
        amount: amount,
        bidder: msg.sender,
        active: true,
        expirationTime: expirationTime 
    });
    bidIds.push(nextBidId);
    nextBidId++;

    emit BidCreated(nextBidId - 1, price, amount, msg.sender);
}

function createOffer(uint256 price, uint256 amount) external override {
    require(price > 0, "Price must be greater than zero");
    require(amount > 0, "Amount must be greater than zero");
    require(validateOfferPrice(price), "Offer price cannot be lower than highest bid");

    require(
        solidus.balanceOf(msg.sender) >= amount,
        "Insufficient SUS balance"
    );

    require(
        solidus.transferFrom(msg.sender, address(this), amount),
        "SUS transfer failed"
    );

  historicalOfferPrices[nextOfferId] = OfferPrice({
    price: price,
    timestamp: block.timestamp
  });
  nextOfferId++;

  emit OfferCreated(nextOfferId - 1, price, amount, msg.sender);

function internal getAveragePriceOfLowestOffersForTemplar(uint256 timeframe) public view returns (uint256) {
  uint256 totalOfferPrice = 0;
  uint256 validOfferCount = 0;

  uint256 thresholdTime = block.timestamp - timeframe; // Calculate timeframe threshold

  // Temporary array to store prices of valid offers within timeframe
  uint256[] memory validOfferPrices = new uint256[](0);

  for (uint256 offerId = 1; offerId < nextOfferId; offerId++) {
    OfferPrice memory offer = historicalOfferPrices[offerId];
    if (offer.timestamp >= thresholdTime) {
      // Check if current offer price is lower than all existing prices
      bool isLowestPrice = true;
      for (uint256 i = 0; i < validOfferPrices.length; i++) {
        if (offer.price >= validOfferPrices[i]) {
          isLowestPrice = false;
          break;
        }
      }

      if (isLowestPrice) {
        totalOfferPrice += offer.price;
        validOfferCount++;
        validOfferPrices.push(offer.price);
      }
    }
  }

  if (validOfferCount == 0) {
    return 0; // No offers within timeframe
  }

  // Calculate average from prices in the temporary array
  uint256 averagePrice = 0;
  for (uint256 i = 0; i < validOfferPrices.length; i++) {
    averagePrice += validOfferPrices[i];
  }
  averagePrice = averagePrice / validOfferCount;

  return averagePrice;
}

    // Set expiration time
    uint256 expirationTime = block.timestamp + expirationPeriod;

    offers[nextOfferId] = Offer({
        id: nextOfferId,
        price: price,
        amount: amount,
        seller: msg.sender,
        active: true,
        expirationTime: expirationTime 
    });
    offerIds.push(nextOfferId);
    nextOfferId++;

    emit OfferCreated(nextOfferId - 1, price, amount, msg.sender);
}

    function cancelBid(uint256 orderId) external override {
        require(bids[orderId].bidder == msg.sender, "Not authorized to cancel this bid");
        require(bids[orderId].active, "Bid is not active");

        bids[orderId].active = false;

        // Remove from bidIds array
        for (uint256 i = 0; i < bidIds.length; i++) {
            if (bidIds[i] == orderId) {
                bidIds[i] = bidIds[bidIds.length - 1];
                bidIds.pop();
                break;
            }
        }

        // Return WEETH to the bidder
        weth.transfer(msg.sender, bids[orderId].price * bids[orderId].amount);

        emit BidCancelled(orderId);
    }

    function cancelOffer(uint256 orderId) external override {
        require(offers[orderId].seller == msg.sender, "Not authorized to cancel this offer");
        require(offers[orderId].active, "Offer is not active");

        offers[orderId].active = false;

        // Remove from offerIds array
        for (uint256 i = 0; i < offerIds.length; i++) {
            if (offerIds[i] == orderId) {
                offerIds[i] = offerIds[offerIds.length - 1];
                offerIds.pop();
                break;
            }
        }

        // Return SUS to the seller
        solidus.transfer(msg.sender, offers[orderId].amount);

        emit OfferCancelled(orderId);
    }

    // -- Kingdom Bid and Offer Functions --
    
    function initializeKingdomBid(uint256 totalSusCirculation) external override {
        require(msg.sender == address(kingdomContract), "Only Kingdom can initialize bid");
        require(kingdomBid.amount == 0, "Kingdom bid already initialized");

        kingdomBid = Bid({
            id: 0, // Special ID for the Kingdom bid
            price: 0.995 ether, // Or the WEETH equivalent based on your oracle
            amount: totalSusCirculation,
            bidder: address(this), // The Kingdom contract address
            active: true
        });
    }

    function updateKingdomOffer() external override {
        require(msg.sender == address(kingdomContract), "Only Kingdom can update offer");

        // Calculate the new kingdomOfferAmount (logic in Kingdom.sol)
        kingdomOfferAmount = kingdomContract.calculateKingdomOfferAmount();
    }

    // Order Matching Logic
    function matchOrders() external override {
        // Expire outdated orders first
        expireOutdatedOrders();
        // 1. Prepare and sort orders
        Bid[] memory activeBids = getActiveBids();
        Offer[] memory activeOffers = getActiveOffers();
        sortBidsDescending(activeBids);
        sortOffersAscending(activeOffers);

        // 2. Match user bids with Kingdom offer
        uint256 bidIndex = 0;
        while (bidIndex < activeBids.length && kingdomOfferAmount > 0) {
            Bid storage bid = bids[activeBids[bidIndex].id];
            uint256 wethEquivalentOf1005Usd = kingdomContract.kingdomMintOfferPrice();
         if (bid.price >= wethEquivalentOf1005Usd) { 
                uint256 matchAmount = min(bid.amount, kingdomOfferAmount);
                executeMatch(bid.bidder, address(kingdomContract), matchAmount, bid.price);
                kingdomOfferAmount -= matchAmount;
                bid.amount -= matchAmount;
                if (bid.amount == 0) {
                    bid.active = false;
                }
            }
            bidIndex++;
        }

        // 3. Match user bids with user offers
        bidIndex = 0;
        uint256 offerIndex = 0;
        while (bidIndex < activeBids.length && offerIndex < activeOffers.length) {
            Bid storage bid = bids[activeBids[bidIndex].id];
            Offer storage offer = offers[activeOffers[offerIndex].id];

            if (bid.price >= offer.price && bid.active && offer.active) {
                uint256 matchAmount = min(bid.amount, offer.amount);
                executeMatch(bid.bidder, offer.seller, matchAmount, offer.price);
                bid.amount -= matchAmount;
                offer.amount -= matchAmount;
                if (bid.amount == 0) {
                    bid.active = false;
                }
                if (offer.amount == 0) {
                    offer.active = false;
                }
            }

            // Move to the next bid or offer,depending on which has a lower price
            if (bid.price > offer.price) {
                offerIndex++;
            } else {
                bidIndex++;
            }
        }

        // 4. Match kingdom bid with user offers (only if there are any remaining offers)
        if (kingdomBid.amount > 0 && activeOffers.length > offerIndex) {
            while (offerIndex < activeOffers.length) {
                Offer storage offer = offers[activeOffers[offerIndex].id];
                uint256 wethEquivalentOf995Usd = kingdomContract.kingdomBurnBidPrice();
                  if (offer.price <= wethEquivalentOf995Usd) { // Check Kingdom's bid price
                    uint256 matchAmount = min(offer.amount, kingdomBid.amount);
                    executeMatch(address(kingdomContract), offer.seller, matchAmount, offer.price);
                    kingdomBid.amount -= matchAmount;
                    offer.amount -= matchAmount;
                    if (offer.amount == 0) {
                        offer.active = false;
                    }
                }
                offerIndex++;
            }
        }

        // 5. Clean up inactive orders
        cleanupOrders();
    }
  // Function to expire outdated orders
    function expireOutdatedOrders() private {
        // Loop through bidIds
        for (uint256 i = 0; i < bidIds.length; i++) {
            uint256 bidId = bidIds[i];
            if (bids[bidId].expirationTime < block.timestamp && bids[bidId].active == true) { 
                cancelBid(bidId);
            }
        }

        // Loop through offerIds
        for (uint256 i = 0; i < offerIds.length; i++) {
            uint256 offerId = offerIds[i];
            if (offers[offerId].expirationTime < block.timestamp && offers[offerId].active == true) {
                cancelOffer(offerId);
            }
        }
    }
  
  // Function to set a new expiration period (optional)
  function setExpirationPeriod(uint256 _newExpirationPeriod) public {
    require(msg.sender == address(kingdomContract), "Only Kingdom can change the expiration time");
    expirationPeriod = _newExpirationPeriod;
  }

function executeMatch(address buyer, address seller, uint256 amount, uint256 price) internal {
    try weth.transferFrom(buyer, seller, amount * price) {
        if (seller == address(kingdomContract)) {
            kingdomContract.kingdomMint(amount);
        } else {
            kingdomContract.kingdomBurn(amount, price);
        }

        if (buyer != address(kingdomContract)) {
              require(
                  solidus.transfer(buyer, amount),
                  "SUS transfer failed"
              );
        emit OrderMatched(bids[bidIndex].id, offers[offerIndex].id, amount, price); // Add this line here
    } 
    catch (bytes memory reason) {
        emit OrderMatchFailed(bids[bidIndex].id, offers[offerIndex].id, string(reason)); // Add this line here
    }   
    
}
    uint256 remainingBidAmount = bids[bidder][susAmount].amount;
    uint256 remainingOfferAmount = offers[offerer][susAmount].amount;

     // Handle partial fills
  if (susAmount < remainingBidAmount && susAmount < remainingOfferAmount) {
    bids[bidder][susAmount].amount -= susAmount;
    offers[offerer][susAmount].amount -= susAmount;
  } else if (susAmount < remainingBidAmount) {
    offers[offerer][susAmount].active = false; // Entire offer filled
    bids[bidder][susAmount].amount -= susAmount;
  } else {
    bids[bidder][susAmount].active = false; // Entire bid filled
    offers[offerer][susAmount].amount -= susAmount;
  }

    // Helper Functions for Sorting and Filtering

    function getActiveBids() internal view returns (Bid[] memory) {
    uint256 activeBidCount = 0;
    for (uint256 i = 0; i < bidIds.length; i++) {
        if (bids[bidIds[i]].active) {
            activeBidCount++;
        }
    }

    Bid[] memory _activeBids = new Bid[](activeBidCount);
    uint256 index = 0;
    for (uint256 i = 0; i < bidIds.length; i++) {
        if (bids[bidIds[i]].active) {
            _activeBids[index] = bids[bidIds[i]];
            index++;
        }
    }
    return _activeBids;
}

function getActiveOffers() internal view returns (Offer[] memory) {
    uint256 activeOfferCount = 0;
    for (uint256 i = 0; i < offerIds.length; i++) {
        if (offers[offerIds[i]].active) {
            activeOfferCount++;
        }
    }

    Offer[] memory _activeOffers = new Offer[](activeOfferCount);
    uint256 index = 0;
    for (uint256 i = 0; i < offerIds.length; i++) {
        if (offers[offerIds[i]].active) {
            _activeOffers[index] = offers[offerIds[i]];
            index++;
        }
    }
    return _activeOffers;
}

function sortBidsDescending(Bid[] memory _bids) internal pure {
    quickSortBids(_bids, int256(0), int256(_bids.length - 1));
}

function sortOffersAscending(Offer[] memory _offers) internal pure {
    quickSortOffers(_offers, int256(0), int256(_offers.length - 1));
}

function quickSortBids(Bid[] memory arr, int256 left, int256 right) internal pure {
    int256 i = left;
    int256 j = right;
    if (i == j) return;
    uint256 pivot = arr[uint256(left + (right - left) / 2)].price;
    while (i <= j) {
        while (arr[uint256(i)].price > pivot) i++;
        while (pivot > arr[uint256(j)].price) j--;
        if (i <= j) {
            (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
            i++;
            j--;
        }
    }
    if (left < j)
        quickSortBids(arr, left, j);
    if (i < right)
        quickSortBids(arr, i, right);
}

function quickSortOffers(Offer[] memory arr, int256 left, int256 right) internal pure {
    int256 i = left;
    int256 j = right;
    if (i == j) return;
    uint256 pivot = arr[uint256(left + (right - left) / 2)].price;
    while (i <= j) {
        while (arr[uint256(i)].price < pivot) i++;
        while (pivot < arr[uint256(j)].price) j--;
        if (i <= j) {
            (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
            i++;
            j--;
        }
    }
    if (left < j)
        quickSortOffers(arr, left, j);
    if (i < right)
        quickSortOffers(arr, i, right);
}

function cleanupOrders() internal {
    // Remove inactive bids
    uint256 bidLength = bidIds.length;
    for (uint256 i = bidLength - 1; i >= 0; i--) {
        uint256 bidId = bidIds[i];
        if (!bids[bidId].active) {
            removeInactiveBid(i);
        }
    }

    // Remove inactive offers
    uint256 offerLength = offerIds.length;
    for (uint256 i = offerLength - 1; i >= 0; i--) {
        uint256 offerId = offerIds[i];
        if (!offers[offerId].active) {
            removeInactiveOffer(i);
        }
    }
}

function removeInactiveBid(uint256 index) internal {
    bidIds[index] = bidIds[bidIds.length - 1];
    bidIds.pop();
}

function removeInactiveOffer(uint256 index) internal {
    offerIds[index] = offerIds[offerIds.length - 1];
    offerIds.pop();
}
    //Events
    event OrderMatched(uint256 bidId, uint256 offerId, uint256 amount, uint256 price);
    event OrderMatchFailed(uint256 bidId, uint256 offerId);
}
}


