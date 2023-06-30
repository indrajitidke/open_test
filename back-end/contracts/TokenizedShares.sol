// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TokenizedShares is ReentrancyGuard {
    struct Share {
        address owner;
        string tokenName;
        uint256 buyAmount;
        uint256 buyPrice;
    }

    using SafeMath for uint256;

    address public owner;
    mapping(address => Share[]) public shareOwner;

    event ShareBought(
        address indexed buyer,
        uint256 buyAmount,
        uint256 totalPrice
    );
    event ShareSold(
        address indexed seller,
        uint256 sellAmount,
        uint256 totalPrice
    );

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    receive() external payable {}

    function buyShares(
        uint256 buyAmount,
        uint256 _currentPriceInUSD,
        uint256 exchangeRate,
        string memory name,
        address tokenAddress
    ) external payable nonReentrant {
        require(buyAmount > 0, "Buy amount must be greater than zero");

      uint256 weiAmount = (uint256(buyAmount) * exchangeRate + uint256(50)) / uint256(100);

        require(msg.value >= weiAmount, " < weiAmount");

        Share memory newShare = Share(
            msg.sender,
            name,
            buyAmount,
            _currentPriceInUSD
        );
        shareOwner[msg.sender].push(newShare);

        uint256 amt = buyAmount * 10**18;
        uint256 Amt = _currentPriceInUSD * 10**18;

        uint256 decimals = 10**18;
        uint256 mintAmt = amt.mul(decimals).div(Amt);

        ERC20(tokenAddress).mint(msg.sender, mintAmt);

        // Refund any excess Ether back to the buyer
        if (msg.value > weiAmount) {
            uint256 refundAmount = msg.value - weiAmount;
            payable(msg.sender).transfer(refundAmount);
        }

        emit ShareBought(msg.sender, buyAmount, weiAmount);
    }

    function sellShares(
        uint256 shareIndex,
        uint256 sellAmount,
        uint256 _currentPriceInUSD,
        uint256 exchangeRate,
        address tokenAddress
    ) external nonReentrant {
        require(sellAmount > 0, "Sell amount must be greater than zero");

        Share[] storage shares = shareOwner[msg.sender];
        require(shares.length > 0, "No shares owned by the user");
        require(shareIndex < shares.length, "Invalid share index");

        Share storage share = shares[shareIndex];
        uint256 buyAmount = share.buyAmount;

        require(buyAmount >= sellAmount, "Insufficient shares to sell");

         
        uint256 totalPayment = (uint(_currentPriceInUSD) * uint(sellAmount)) /
           uint(share.buyPrice);
      uint256 totalPaymentInWei = (uint256(totalPayment) * exchangeRate + uint256(50)) / uint256(100);



          uint256 amt = sellAmount * 10**18;
        uint256 Amt = share.buyPrice * 10**18;

        uint256 decimals = 10**18;
        uint256 burnAmt = amt.mul(decimals).div(Amt);

        ERC20(tokenAddress).burn(msg.sender, burnAmt);

        // Update the share and the user's balances
        if (buyAmount == sellAmount) {
            // If selling all shares in this entry, delete the share entry
            delete shares[shareIndex];
            if (shares.length > 1) {
                shares[shareIndex] = shares[shares.length - 1];
            }
            shares.pop();
        } else {
            // If selling a portion of shares in this entry, update the remaining shares
            share.buyAmount -= sellAmount;
        }


        // Transfer the payment to the seller
        (bool paymentSuccess, ) = payable(msg.sender).call{
            value: totalPaymentInWei
        }("");
        require(paymentSuccess, "Payment failed");

        emit ShareSold(msg.sender, sellAmount, totalPaymentInWei);
    }

    function requiredEth(uint256 amount, uint256 exchangeRate)
        public
        pure
        returns (uint256 weiAmount)
    {
       weiAmount = (uint256(amount) * exchangeRate + uint256(50)) / uint256(100);
    }

    function getUserShares(address user) public view returns (Share[] memory) {
        Share[] storage allShares = shareOwner[user];
        uint256 ownedSharesCount = 0;

        for (uint256 i = 0; i < allShares.length; i++) {
            if (allShares[i].owner == user) {
                ownedSharesCount++;
            }
        }

        Share[] memory ownedShares = new Share[](ownedSharesCount);
        uint256 ownedSharesIndex = 0;

        for (uint256 i = 0; i < allShares.length; i++) {
            if (allShares[i].owner == user) {
                ownedShares[ownedSharesIndex] = allShares[i];
                ownedSharesIndex++;
            }
        }

        return ownedShares;
    }

    function updateShare(
        address user,
        uint256 index,
        Share memory newShare
    ) external  {
        Share[] storage shares = shareOwner[user];
        require(index < shares.length, "Invalid share index");
        shares[index] = newShare;
    }
}
