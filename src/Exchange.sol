// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Exchange {
    address public tokenAddress;

    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "invalid token address");

        tokenAddress = _tokenAddress;
    }

    function addLiquidity(uint256 _tokenAmount) public payable {
        IERC20 token = IERC20(tokenAddress);
        bool success = token.transferFrom(msg.sender, address(this), _tokenAmount);

        require(success, "failed to add liquidity");
    }

    function getReserve() public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    function getPrice(uint256 inputReserve, uint256 outputReserve) public pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");

        return (inputReserve) / outputReserve;
    }

    /// @notice Δy = Δxy / (x + Δx) Calcule la qté du jetons à obtenir (Ether/Token) ou (Token/Ether)
    /// @param inputAmount Δx: Jeton que l'on apporte
    /// @param inputReserve x: Réserve du jeton que l'on apporte
    /// @param outputReserve y: Réserve du jeton que l'on veut en échange
    function getAmount(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve)
        private
        pure
        returns (uint256)
    {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");

        return (inputAmount * outputReserve) / (inputReserve + inputAmount);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Détermine la quantité de Token à obtenir en fournissant `_ethSold` de Ethers
    /// @param _ethSold Quantité de Ethers que l'on apporte
    /// @return La quantité de Token à obtenir
    function getTokenAmount(uint256 _ethSold) public view returns (uint256) {
        require(_ethSold > 0, "ethSold is too small");

        uint256 etherReserve = address(this).balance;

        uint256 tokenReserve = getReserve();

        return getAmount(_ethSold, etherReserve, tokenReserve);
    }

    /// @notice Détermine la quantité de Ether à obtenir en fournissant `_tokenSold` de Tokens
    /// @param _tokenSold Quantité de Ether que l'on apporte
    /// @return La quantité de Ether à obtenir
    function getEthAmount(uint256 _tokenSold) public view returns (uint256) {
        require(_tokenSold > 0, "tokenSold is too small");

        uint256 tokenReserve = getReserve();

        // outputReserve
        uint256 ethReserve = address(this).balance;

        return getAmount(_tokenSold, tokenReserve, ethReserve);
    }

    function ethToTokenSwap(uint256 _minTokens) public payable {
        uint256 tokenReserve = getReserve();

        uint256 tokensBought = getAmount(msg.value, address(this).balance - msg.value, tokenReserve);

        require(tokensBought >= _minTokens, "insufficient output amount");

        bool success = IERC20(tokenAddress).transfer(msg.sender, tokensBought);

        require(success, "transfer failed");
    }

    function tokenToEthSwap(uint256 _tokenSold, uint256 _minEth) public {
        uint256 tokenReserve = getReserve();
        uint256 ethBought = getAmount(_tokenSold, tokenReserve, address(this).balance);

        require(ethBought >= _minEth, "Insufficient output amount");

        // Transfert des Tokens à l'adresse du contract Exchange
        bool success = IERC20(tokenAddress).transferFrom(msg.sender, address(this), ethBought);

        require(success, "Token to Eth swap failed");

        // Transfert des Ethers reçu après le swap à l'adresse de `msg.sender`
        payable(msg.sender).transfer(ethBought);
    }
}
