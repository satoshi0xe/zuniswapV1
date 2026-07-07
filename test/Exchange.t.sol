// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;
import {Test, console2} from "forge-std/Test.sol";
import {Exchange} from "../src/Exchange.sol";
import {Token} from "../src/Token.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ExchangeTest is Test {
    //////////////////////////////////////////
    /// address(this) == ExchangeTest
    /////////////////////////////////////////

    // 1000 ETH et 2000 Tokens (avec 18 décimales
    uint256 constant TOKEN_ALLOWED_TO_SPEND = 2000 ether;
    uint256 constant ETHER_ALLOWED_TO_SPEND = 1000 ether;
    uint256 constant INITIAL_TOKEN = 3000 ether;

    /*//////////////////////////////////////////////////////////////
                    Token ERC20 ↔ ETH Exchange                  
    //////////////////////////////////////////////////////////////*/

    Token token;
    Exchange exchange;

    /*//////////////////////////////////////////////////////////////
                       GUIDE TO FOLLOW
        1. Allouer la quantité de Tokens à dépenser
        2. Ajouter de la liquidité dans la pool (paire: ERC20 Token / ETH)
        3. Action à faire...
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        // Mint de `Tokens` à l'adresse du contrat ExchangeTest
        token = new Token("NerdToken", "NTK", INITIAL_TOKEN);

        exchange = new Exchange(address(token));

        // -------------------------------------------------------------
        // STEP 1: Allouer la quantité de Tokens à dépenser (Approve)
        // -------------------------------------------------------------
        token.approve(address(exchange), TOKEN_ALLOWED_TO_SPEND);

        // -------------------------------------------------------------
        // STEP 2: Ajouter de la liquidité dans la pool (Token / ETH)
        // -------------------------------------------------------------
        exchange.addLiquidity{value: ETHER_ALLOWED_TO_SPEND}(
            TOKEN_ALLOWED_TO_SPEND
        );
    }

    function test_ExchangeTestInitialBalance() public view {
        assertEq(token.balanceOf(address(this)), INITIAL_TOKEN);
    }

    function test_LiquidityAddSuccessfully() public view {
        /// @dev Vérifier que le solde d'Ether du contrat Exchange == ETHER_ALLOWED_TO_SPEND
        assertEq(address(exchange).balance, ETHER_ALLOWED_TO_SPEND); // Balance de ether

        /// @dev S'assurer que la réserve de Token du contrat Exchange == TOKEN_ALLOWED_TO_SPEND
        assertEq(exchange.getReserve(), TOKEN_ALLOWED_TO_SPEND); // Balance de Token
    }

    function test_getPriceCorrectly() public view {
        uint256 tokenReserve = exchange.getReserve();
        uint256 etherReserve = address(exchange).balance;

        /// Prix du Ether/Token
        /// 1 Ether equivaut à combien de Tokens ?
        uint256 etherPerTokenPricing = exchange.getPrice(
            etherReserve,
            tokenReserve
        );

        /// Prix Token/Ether
        /// 1 Token équivaut à combien de Ethers ?
        uint256 tokenPerTokenPricing = exchange.getPrice(
            tokenReserve,
            etherReserve
        );

        console2.log("Eth/Token: ", etherPerTokenPricing);
        console2.log("Token/Eth: ", tokenPerTokenPricing);

        assert(etherPerTokenPricing == 500);
        assert(tokenPerTokenPricing == 2000);
    }

    function test_getTokenAmount() public view {
        uint256 etherToSwap = 2 ether;
        uint256 tokenToSwap = 2 ether;

        // (2 ether * 3000 ether) / (2 eth + 2000 ether)
        uint256 tokensOut = exchange.getTokenAmount(etherToSwap);
        uint256 ethersOut = exchange.getEthAmount(tokenToSwap);

        assertEq(tokensOut, 3992015968063872255);
        assertEq(ethersOut, 999000999000999000);
    }

    function test_cannotDrainPoolCauseSlippageAffectsPrice() public view {
        uint256 etherToSwap = 1000 ether;
        uint256 tokenToSwap = 2000 ether;

        /// Combien de Tokens je reçois en donnant 1000 Ethers
        uint256 tokensOut = exchange.getTokenAmount(etherToSwap);

        /// Combien de Ethers je reçois en donnant 2000 Tokens
        uint256 ethersOut = exchange.getEthAmount(tokenToSwap);

        console2.log("Tokens received: ", tokensOut / 1e18);
        console2.log("Ethers received: ", ethersOut / 1e18);

        assert(tokensOut == 1000000000000000000000);
        assert(ethersOut == 500000000000000000000);
    }
}
