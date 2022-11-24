// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

contract DEX {
    /* ========== GLOBAL VARIABLES ========== */

    using SafeMath for uint256; 
    IERC20 token; 
    uint256 public totalLiquidity;
    mapping (address => uint256) public liquidity;

    event EthToTokenSwap(address _to, string _message, uint256 _ethValue, uint256 _tokenValue);
    event TokenToEthSwap(address _to, string _messsage, uint256 _tokenValue, uint256 _ethValue);
    event LiquidityProvided(address _from, uint256 _liquidityProvided, uint256 _ethAmount, uint256 _tokenAmount);
    event LiquidityRemoved(address _from, uint256 _amount, uint256 _ethAmount, uint256 _tokenAmount);

    constructor(address token_addr) public {
        token = IERC20(token_addr); //specifies the token address that will hook into the interface and be used through the variable 'token'
    }


    /**
     * @notice initializes amount of tokens that will be transferred to the DEX itself from the erc20 contract mintee (and only them based on how Balloons.sol is written). Loads contract up with both ETH and Balloons.
     * @param tokens amount to be transferred to DEX
     * @return totalLiquidity is the number of LPTs minting as a result of deposits made to DEX contract
     * NOTE: since ratio is 1:1, this is fine to initialize the totalLiquidity (wrt to balloons) as equal to eth balance of contract.
     */

    function init(uint256 tokens) public payable returns (uint256) {
        require(totalLiquidity==0,"DEX:init - already has liquidity");
        totalLiquidity = address(this).balance;
        liquidity[msg.sender] = totalLiquidity;
        require(token.transferFrom(msg.sender, address(this), tokens));
        return totalLiquidity;
    }
       
    function price( uint256 xInput, uint256 xReserves, uint256 yReserves) public pure returns (uint256 yOutput) {
        uint256 xInputWithFee = xInput.mul(997);
        uint256 numerator = xInputWithFee.mul(yReserves);
        uint256 denominator = (xReserves.mul(1000)).add(xInputWithFee);
        return (numerator / denominator);
    }


    /**
     * @notice returns liquidity for a user. Note this is not needed typically due to the `liquidity()` mapping variable being public and having a getter as a result. This is left though as it is used within the front end code (App.jsx).
     * if you are using a mapping liquidity, then you can use `return liquidity[lp]` to get the liquidity for a user.
     *
     */
    function getLiquidity(address lp) public view returns (uint256) {}


    function ethToToken() public payable returns (uint256 totalTokens) {
        require(msg.value > 0.0001 ether, "value neds to be higher than 0");
        uint256 ethLiquidity = address(this).balance;
        uint256 tokenLiquidity = token.balanceOf(address(this));
        uint256 tokenOutput = price(msg.value, ethLiquidity, tokenLiquidity ); 

        require(token.transfer(msg.sender, tokenOutput), "ethToToken(): reverted swap.");
        emit EthToTokenSwap(msg.sender, "Eth to Balloons", msg.value, tokenOutput);
        return tokenOutput;
    }

    function tokenToEth(uint256 tokenInput) public returns (uint256 totalEth) {
        require(tokenInput > 0, "token amount needs to be large than 0!");
        uint256 ethLiquidity = address(this).balance;
        uint256 tokenLiquidity = token.balanceOf(address(this));
        uint256 ethOutput = price(tokenInput, tokenLiquidity, ethLiquidity );
        require(token.transferFrom(msg.sender, address(this), tokenInput), "transfer unsuccessful");
        emit TokenToEthSwap(msg.sender, "Eth to Balloons", tokenInput, ethOutput);
        return ethOutput;     
    }

  
    function deposit() public payable returns (uint256 tokensDeposited) {
        require(msg.value > 0, "can't deposit 0");
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethReserve = address(this).balance.sub(msg.value);
        uint256 tokenDeposit = (msg.value.mul(tokenReserve) / ethReserve).add(1);
        uint256 liquidityMinted = msg.value.mul(totalLiquidity) / ethReserve;
        liquidity[msg.sender] = liquidity[msg.sender].add(liquidityMinted);
        totalLiquidity = totalLiquidity.add(liquidityMinted);

        require(token.transferFrom(msg.sender, address(this), tokenDeposit));
        emit LiquidityProvided(msg.sender, liquidityMinted, msg.value, tokenDeposit);
        return tokenDeposit;
    }

  
    function withdraw(uint256 amount) public returns (uint256 eth_amount, uint256 token_amount) {
        require(amount <= liquidity[msg.sender], "cant withdraw more than your current balance");
        uint256 tokenLiquidity = token.balanceOf(address(this));
        uint256 ethLiquidity = address(this).balance;
        uint256 ethWithdraw = amount.mul(ethLiquidity / totalLiquidity) ;

        uint256 tokenWithdraw = amount.mul(tokenLiquidity) / totalLiquidity;
        liquidity[msg.sender] = liquidity[msg.sender].sub(amount);
        totalLiquidity = totalLiquidity.sub(amount);
        (bool sent,) = payable(msg.sender).call{value: ethWithdraw} ("");
        require(sent, "withdraw(): revert in transferring eth to you!");
        require(token.transfer(msg.sender, tokenWithdraw),"failure sending tokens");
        emit LiquidityRemoved(msg.sender, amount, ethWithdraw, tokenWithdraw);
        return(ethWithdraw, tokenWithdraw);        
    }
}
