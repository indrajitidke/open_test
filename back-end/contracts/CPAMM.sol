// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./TokenizedShares.sol";

contract CPAMM {
    struct ShareBalances {
        mapping(string => uint256) balance;
    }

    mapping(address => ShareBalances) private userShare;
    mapping(address => IERC20) public tokens;
    mapping(address => uint256) public reserves;
    uint256 public totalSupply;
    TokenizedShares public tokenizedSharesContract;

    constructor(address payable _tokenizedSharesContract) {
        tokenizedSharesContract = TokenizedShares(_tokenizedSharesContract);
    }

    function _mint(
        address _token1Address,
        address _token2Address,
        address _to,
        uint256 _amount
    ) private {
        string memory tokenKey = string(
            abi.encodePacked(_token1Address, _token2Address)
        );
        userShare[_to].balance[tokenKey] += _amount;
        totalSupply += _amount;
    }

    function _burn(
        address _token1Address,
        address _token2Address,
        address _from,
        uint256 _amount
    ) private {
        string memory tokenKey = string(
            abi.encodePacked(_token1Address, _token2Address)
        );
        userShare[_from].balance[tokenKey] -= _amount;
        totalSupply -= _amount;
    }

    function _update(
        uint256 _reserve1,
        uint256 _reserve2,
        address token1Addr,
        address token2Addr
    ) private {
        reserves[token1Addr] = _reserve1;
        reserves[token2Addr] = _reserve2;
    }

    function _approve(address tokenAddress, uint256 amount) private {
        IERC20 token = tokens[tokenAddress];
        token.approve(address(this), amount);
    }

    function _transferTokens(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) private {
        IERC20 token = tokens[tokenAddress];
        token.transfer(recipient, amount);
    }

    function getSwapAmount(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        uint256 _tokenInPrice,
        uint256 _tokenOutPrice
    ) private pure returns (uint256 amountOut) {
        require(_amountIn > 0, "amtIn = 0");

        bool isTokenIn = _tokenIn == _tokenOut;
        uint256 tokenInPrice = isTokenIn ? _tokenInPrice : _tokenOutPrice;
        uint256 tokenOutPrice = isTokenIn ? _tokenOutPrice : _tokenInPrice;

        if (isTokenIn) {
            amountOut = (_amountIn * tokenInPrice) / tokenOutPrice;
        } else {
            amountOut = (_amountIn * tokenOutPrice) / tokenInPrice;
        }
    }

 
 
    function swap(
        address tokenIn,
        uint256 amountIn,
        address token1,
        address token2,
        string memory token1Name,
        string memory token2Name,
        uint256 token1Price,
        uint256 token2Price
    ) external  returns (uint amountOut) {
        tokens[tokenIn] = IERC20(tokenIn);
        tokens[token1] = IERC20(token1);
        tokens[token2] = IERC20(token2);

        amountOut = getSwapAmount(
            tokenIn,
            amountIn,
            token1,
            token1Price,
            token2Price
        );

        // Check if the user has tokens or if the token name matches the share's token name and the buy amount is equal to amountIn
        bool hasTokens = tokens[tokenIn].balanceOf(msg.sender) >= amountIn;
        require(hasTokens,"dont enough tokens");
      
        bool isValidShare = false;
        TokenizedShares.Share[] memory userShares = tokenizedSharesContract
            .getUserShares(msg.sender);

        for (uint256 i = 0; i < userShares.length; i++) {
            TokenizedShares.Share memory share = userShares[i];

            if (
                (tokenIn == token1 &&
                    keccak256(abi.encodePacked(share.tokenName)) ==
                    keccak256(abi.encodePacked(token1Name)) &&
                    tokens[token1].balanceOf(msg.sender) >= amountIn) ||
                (tokenIn == token2 &&
                    keccak256(abi.encodePacked(share.tokenName)) ==
                    keccak256(abi.encodePacked(token2Name)) &&
                    tokens[token2].balanceOf(msg.sender) >= amountIn)
            ) {
                isValidShare = true;
          
                require(
                    hasTokens || isValidShare,
                    "Insufficient tokens or invalid share"
                );

                // Check if the share matches the token being swapped
                if (isValidShare) {
                    uint amt = (tokenIn == token1)
                        ? (uint256(token1Price) * uint256(share.buyAmount)) /
                            uint256(share.buyPrice)
                        : (uint256(token2Price) * uint256(share.buyAmount)) /
                            uint256(share.buyPrice);

                    // Update the token details with the new token being swapped to
                    share.tokenName = (tokenIn == token1)
                        ? token2Name
                        : token1Name;
                    share.buyPrice = (tokenIn == token1)
                        ? token2Price
                        : token1Price;
                    share.buyAmount = amt;

                    // Update the share details in the TokenizedShares contract
                    tokenizedSharesContract.updateShare(msg.sender, i, share);
                }

                break;
            }
        }

        tokens[tokenIn].transferFrom(msg.sender, address(this), amountIn);
        // Transfer tokenOut to msg.sender
        if (tokenIn == token1) {
            tokens[token2].transfer(msg.sender, amountOut);
        } else {
            tokens[token1].transfer(msg.sender, amountOut);
        }
    }


    function addLiquidity(
        uint256 _amount1,
        uint256 _amount2,
        address token1Addr,
        address token2Addr
    ) external returns (uint256 shares) {
        tokens[token1Addr] = IERC20(token1Addr);
        tokens[token2Addr] = IERC20(token2Addr);

        IERC20 token1 = tokens[token1Addr];
        IERC20 token2 = tokens[token2Addr];

        token1.transferFrom(msg.sender, address(this), _amount1);
        token2.transferFrom(msg.sender, address(this), _amount2);

        if (reserves[token1Addr] > 0 || reserves[token2Addr] > 0) {
            require(
                reserves[token1Addr] * _amount2 ==
                    reserves[token2Addr] * _amount1,
                "dy/dx != y/x"
            );
        }

        if (totalSupply == 0) {
            shares = _sqrt(_amount1 * _amount2);
        } else {
            shares = _min(
                (_amount1 * totalSupply) / reserves[token1Addr],
                (_amount2 * totalSupply) / reserves[token2Addr]
            );
        }
        require(shares > 0, "shares = 0");
        _mint(token1Addr, token2Addr, msg.sender, shares);

        _update(
            token1.balanceOf(address(this)),
            token2.balanceOf(address(this)),
            token1Addr,
            token2Addr
        );
    }

    function removeLiquidity(
        uint256 _shares,
        address token1Addr,
        address token2Addr
    ) external returns (uint256 amount1, uint256 amount2) {
        IERC20 token1 = tokens[token1Addr];
        IERC20 token2 = tokens[token2Addr];

        uint256 bal1 = token1.balanceOf(address(this));
        uint256 bal2 = token2.balanceOf(address(this));

        amount1 = (_shares * bal1) / totalSupply;
        amount2 = (_shares * bal2) / totalSupply;

        require(amount1 > 0 && amount2 > 0, "amt1 or amt2 = 0");

        _burn(token1Addr, token2Addr, msg.sender, _shares);

        _update(bal1 - amount1, bal2 - amount2, token1Addr, token2Addr);
        token1.transfer(msg.sender, amount1);
        token2.transfer(msg.sender, amount2);
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }

    function getShareCount(address _token1Address, address _token2Address)
        external
        view
        returns (uint256)
    {
        string memory tokenKey = string(
            abi.encodePacked(_token1Address, _token2Address)
        );
        return userShare[msg.sender].balance[tokenKey];
    }

    event LiquidityAdded(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 shares
    );
    event LiquidityRemoved(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 shares
    );
}
