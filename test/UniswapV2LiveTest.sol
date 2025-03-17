// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/UniswapV2Factory.sol";
import "../src/UniswapV2Router.sol";
import "../src/UniswapV2Pair.sol";
import "../src/WETH9.sol";
import "../src/MyERC20Token.sol";
import "../src/interfaces/IUniswapV2Pair.sol";

contract UniswapV2LiveTest is Test {
    // Use deployed contract addresses
    address constant WETH_ADDRESS = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    address constant TOKEN_A_ADDRESS = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    address constant TOKEN_B_ADDRESS = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
    address constant FACTORY_ADDRESS = 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707;
    address constant ROUTER_ADDRESS = 0x0165878A594ca255338adfa4d48449f69242Eb8F;
    
    UniswapV2Factory public factory;
    UniswapV2Router public router;
    WETH9 public weth;
    MyERC20Token public tokenA;
    MyERC20Token public tokenB;
    
    address public user;
    uint256 public constant INITIAL_AMOUNT = 1000000 * 10**18;
    
    function setUp() public {
        // Use the current sender as the test user
        user = address(this);
        
        // Connect to deployed contracts
        factory = UniswapV2Factory(FACTORY_ADDRESS);
        router = UniswapV2Router( payable(ROUTER_ADDRESS));
        weth = WETH9( payable(WETH_ADDRESS));
        tokenA = MyERC20Token(TOKEN_A_ADDRESS);
        tokenB = MyERC20Token(TOKEN_B_ADDRESS);
        
        // 铸造代币给测试合约
        // 注意：这要求MyERC20Token合约允许任何人铸造代币，或者测试账户有铸造权限
        tokenA.mint(user, INITIAL_AMOUNT);
        tokenB.mint(user, INITIAL_AMOUNT);
        
        // 确保我们有足够的ETH
        vm.deal(user, 100 ether);
    }
    
    function testFactoryCreatePair() public {
        address pairAddress = factory.createPair(TOKEN_A_ADDRESS, TOKEN_B_ADDRESS);
        assertNotEq(pairAddress, address(0), "Pair creation failed");
        
        address retrievedPair = factory.getPair(TOKEN_A_ADDRESS, TOKEN_B_ADDRESS);
        assertEq(retrievedPair, pairAddress, "Retrieved pair address does not match");
        
        assertEq(factory.allPairsLength(), 1, "Incorrect number of pairs");
    }
    
    function testAddLiquidity() public {
        // Approve Router to use tokens
        tokenA.approve(ROUTER_ADDRESS, INITIAL_AMOUNT);
        tokenB.approve(ROUTER_ADDRESS, INITIAL_AMOUNT);
        
        // Add liquidity
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 2000 * 10**18;
        
        (uint256 actualA, uint256 actualB, uint256 liquidity) = router.addLiquidity(
            TOKEN_A_ADDRESS,
            TOKEN_B_ADDRESS,
            amountA,
            amountB,
            0,
            0,
            user,
            block.timestamp + 3600
        );
        
        assertEq(actualA, amountA, "Incorrect amount of tokenA added");
        assertEq(actualB, amountB, "Incorrect amount of tokenB added");
        assertGt(liquidity, 0, "Liquidity tokens amount should be greater than 0");
        
        // Check pair address
        address pairAddress = factory.getPair(TOKEN_A_ADDRESS, TOKEN_B_ADDRESS);
        assertNotEq(pairAddress, address(0), "Pair address should not be zero");
        
        // Check user's liquidity token balance
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        assertEq(pair.balanceOf(user), liquidity, "User's liquidity token balance is incorrect");
    }
    
    function testAddLiquidityETH() public {
        // Approve Router to use tokens
        tokenA.approve(ROUTER_ADDRESS, INITIAL_AMOUNT);
        
        // Add ETH liquidity
        uint256 amountToken = 1000 * 10**18;
        uint256 amountETH = 5 ether;
        
        (uint256 actualToken, uint256 actualETH, uint256 liquidity) = router.addLiquidityETH{value: amountETH}(
            TOKEN_A_ADDRESS,
            amountToken,
            0,
            0,
            user,
            block.timestamp + 3600
        );
        
        assertEq(actualToken, amountToken, "Incorrect amount of token added");
        assertEq(actualETH, amountETH, "Incorrect amount of ETH added");
        assertGt(liquidity, 0, "Liquidity tokens amount should be greater than 0");
        
        // Check pair address
        address pairAddress = factory.getPair(TOKEN_A_ADDRESS, WETH_ADDRESS);
        assertNotEq(pairAddress, address(0), "Pair address should not be zero");
        
        // Check user's liquidity token balance
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        assertEq(pair.balanceOf(user), liquidity, "User's liquidity token balance is incorrect");
    }
    
    function testSwapExactTokensForTokens() public {
        // First add liquidity if not already added
        if (factory.getPair(TOKEN_A_ADDRESS, TOKEN_B_ADDRESS) == address(0)) {
            tokenA.approve(ROUTER_ADDRESS, INITIAL_AMOUNT);
            tokenB.approve(ROUTER_ADDRESS, INITIAL_AMOUNT);
            
            router.addLiquidity(
                TOKEN_A_ADDRESS,
                TOKEN_B_ADDRESS,
                10000 * 10**18,
                10000 * 10**18,
                0,
                0,
                user,
                block.timestamp + 3600
            );
        }
        
        // Execute token swap
        uint256 amountIn = 100 * 10**18;
        uint256 amountOutMin = 90 * 10**18; // Allow 10% slippage
        
        address[] memory path = new address[](2);
        path[0] = TOKEN_A_ADDRESS;
        path[1] = TOKEN_B_ADDRESS;
        
        tokenA.approve(ROUTER_ADDRESS, amountIn);
        
        uint256 tokenBBalanceBefore = tokenB.balanceOf(user);
        
        router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            user,
            block.timestamp + 3600
        );
        
        uint256 tokenBBalanceAfter = tokenB.balanceOf(user);
        
        assertGt(tokenBBalanceAfter, tokenBBalanceBefore, "Token balance should increase after swap");
    }
    
    function testSwapTokensForExactTokens() public {
        // First add liquidity if not already added
        if (factory.getPair(TOKEN_A_ADDRESS, TOKEN_B_ADDRESS) == address(0)) {
            tokenA.approve(ROUTER_ADDRESS, INITIAL_AMOUNT);
            tokenB.approve(ROUTER_ADDRESS, INITIAL_AMOUNT);
            
            router.addLiquidity(
                TOKEN_A_ADDRESS,
                TOKEN_B_ADDRESS,
                10000 * 10**18,
                10000 * 10**18,
                0,
                0,
                user,
                block.timestamp + 3600
            );
        }
        
        // Execute token swap
        uint256 amountOut = 100 * 10**18;
        uint256 amountInMax = 120 * 10**18; // Allow maximum payment of 120 tokens
        
        address[] memory path = new address[](2);
        path[0] = TOKEN_A_ADDRESS;
        path[1] = TOKEN_B_ADDRESS;
        
        tokenA.approve(ROUTER_ADDRESS, amountInMax);
        
        uint256 tokenABalanceBefore = tokenA.balanceOf(user);
        uint256 tokenBBalanceBefore = tokenB.balanceOf(user);
        
        router.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            user,
            block.timestamp + 3600
        );
        
        uint256 tokenABalanceAfter = tokenA.balanceOf(user);
        uint256 tokenBBalanceAfter = tokenB.balanceOf(user);
        
        assertLt(tokenABalanceAfter, tokenABalanceBefore, "Token A balance should decrease");
        assertEq(tokenBBalanceAfter - tokenBBalanceBefore, amountOut, "Should receive exact amount of token B");
    }
    
    function testSwapExactETHForTokens() public {
        // First add ETH liquidity if not already added
        if (factory.getPair(TOKEN_A_ADDRESS, WETH_ADDRESS) == address(0)) {
            tokenA.approve(ROUTER_ADDRESS, INITIAL_AMOUNT);
            
            router.addLiquidityETH{value: 10 ether}(
                TOKEN_A_ADDRESS,
                10000 * 10**18,
                0,
                0,
                user,
                block.timestamp + 3600
            );
        }
        
        // Execute ETH to token swap
        uint256 amountOutMin = 90 * 10**18; // Minimum expected token amount
        uint256 ethAmount = 1 ether;
        
        address[] memory path = new address[](2);
        path[0] = WETH_ADDRESS;
        path[1] = TOKEN_A_ADDRESS;
        
        uint256 tokenBalanceBefore = tokenA.balanceOf(user);
        
        router.swapExactETHForTokens{value: ethAmount}(
            amountOutMin,
            path,
            user,
            block.timestamp + 3600
        );
        
        uint256 tokenBalanceAfter = tokenA.balanceOf(user);
        
        assertGt(tokenBalanceAfter, tokenBalanceBefore, "Token balance should increase");
    }
    
    function testSwapTokensForExactETH() public {
        // First add ETH liquidity if not already added
        if (factory.getPair(TOKEN_A_ADDRESS, WETH_ADDRESS) == address(0)) {
            tokenA.approve(ROUTER_ADDRESS, INITIAL_AMOUNT);
            
            router.addLiquidityETH{value: 10 ether}(
                TOKEN_A_ADDRESS,
                10000 * 10**18,
                0,
                0,
                user,
                block.timestamp + 3600
            );
        }
        
        // Execute token to ETH swap
        uint256 ethAmountOut = 1 ether;
        uint256 tokenAmountInMax = 1200 * 10**18;
        
        address[] memory path = new address[](2);
        path[0] = TOKEN_A_ADDRESS;
        path[1] = WETH_ADDRESS;
        
        tokenA.approve(ROUTER_ADDRESS, tokenAmountInMax);
        
        uint256 ethBalanceBefore = user.balance;
        
        router.swapTokensForExactETH(
            ethAmountOut,
            tokenAmountInMax,
            path,
            user,
            block.timestamp + 3600
        );
        
        uint256 ethBalanceAfter = user.balance;
        
        assertEq(ethBalanceAfter - ethBalanceBefore, ethAmountOut, "Should receive exact amount of ETH");
    }
    
    function testSwapExactTokensForETH() public {
        // First add ETH liquidity if not already added
        if (factory.getPair(TOKEN_A_ADDRESS, WETH_ADDRESS) == address(0)) {
            tokenA.approve(ROUTER_ADDRESS, INITIAL_AMOUNT);
            
            router.addLiquidityETH{value: 10 ether}(
                TOKEN_A_ADDRESS,
                10000 * 10**18,
                0,
                0,
                user,
                block.timestamp + 3600
            );
        }
        
        // Execute token to ETH swap
        uint256 tokenAmount = 100 * 10**18;
        uint256 ethAmountOutMin = 0.09 ether; // Minimum expected ETH amount
        
        address[] memory path = new address[](2);
        path[0] = TOKEN_A_ADDRESS;
        path[1] = WETH_ADDRESS;
        
        tokenA.approve(ROUTER_ADDRESS, tokenAmount);
        
        uint256 ethBalanceBefore = user.balance;
        
        router.swapExactTokensForETH(
            tokenAmount,
            ethAmountOutMin,
            path,
            user,
            block.timestamp + 3600
        );
        
        uint256 ethBalanceAfter = user.balance;
        
        assertGt(ethBalanceAfter, ethBalanceBefore, "ETH balance should increase");
    }
    
    function testSwapETHForExactTokens() public {
        // First add ETH liquidity if not already added
        if (factory.getPair(TOKEN_A_ADDRESS, WETH_ADDRESS) == address(0)) {
            tokenA.approve(ROUTER_ADDRESS, INITIAL_AMOUNT);
            
            router.addLiquidityETH{value: 10 ether}(
                TOKEN_A_ADDRESS,
                10000 * 10**18,
                0,
                0,
                user,
                block.timestamp + 3600
            );
        }
        
        // Execute ETH to token swap
        uint256 tokenAmountOut = 100 * 10**18;
        uint256 ethAmountInMax = 1 ether;
        
        address[] memory path = new address[](2);
        path[0] = WETH_ADDRESS;
        path[1] = TOKEN_A_ADDRESS;
        
        uint256 tokenBalanceBefore = tokenA.balanceOf(user);
        
        router.swapETHForExactTokens{value: ethAmountInMax}(
            tokenAmountOut,
            path,
            user,
            block.timestamp + 3600
        );
        
        uint256 tokenBalanceAfter = tokenA.balanceOf(user);
        
        assertEq(tokenBalanceAfter - tokenBalanceBefore, tokenAmountOut, "Should receive exact amount of tokens");
    }
    
    function testRemoveLiquidity() public {
        // First add liquidity if not already added
        address pairAddress = factory.getPair(TOKEN_A_ADDRESS, TOKEN_B_ADDRESS);
        uint256 liquidity;
        
        if (pairAddress == address(0)) {
            tokenA.approve(ROUTER_ADDRESS, INITIAL_AMOUNT);
            tokenB.approve(ROUTER_ADDRESS, INITIAL_AMOUNT);
            
            (,, liquidity) = router.addLiquidity(
                TOKEN_A_ADDRESS,
                TOKEN_B_ADDRESS,
                1000 * 10**18,
                1000 * 10**18,
                0,
                0,
                user,
                block.timestamp + 3600
            );
            
            pairAddress = factory.getPair(TOKEN_A_ADDRESS, TOKEN_B_ADDRESS);
        } else {
            IUniswapV2Pair existingPair = IUniswapV2Pair(pairAddress);
            liquidity = existingPair.balanceOf(user);
            
            // If user doesn't have liquidity, add some
            if (liquidity == 0) {
                tokenA.approve(ROUTER_ADDRESS, INITIAL_AMOUNT);
                tokenB.approve(ROUTER_ADDRESS, INITIAL_AMOUNT);
                
                (,, liquidity) = router.addLiquidity(
                    TOKEN_A_ADDRESS,
                    TOKEN_B_ADDRESS,
                    1000 * 10**18,
                    1000 * 10**18,
                    0,
                    0,
                    user,
                    block.timestamp + 3600
                );
            }
        }
        
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        
        // Approve Router to use liquidity tokens
        pair.approve(ROUTER_ADDRESS, liquidity);
        
        uint256 tokenABalanceBefore = tokenA.balanceOf(user);
        uint256 tokenBBalanceBefore = tokenB.balanceOf(user);
        
        // Remove liquidity
        (uint256 amountA, uint256 amountB) = router.removeLiquidity(
            TOKEN_A_ADDRESS,
            TOKEN_B_ADDRESS,
            liquidity,
            0,
            0,
            user,
            block.timestamp + 3600
        );
        
        uint256 tokenABalanceAfter = tokenA.balanceOf(user);
        uint256 tokenBBalanceAfter = tokenB.balanceOf(user);
        
        assertEq(tokenABalanceAfter - tokenABalanceBefore, amountA, "Incorrect amount of tokenA returned");
        assertEq(tokenBBalanceAfter - tokenBBalanceBefore, amountB, "Incorrect amount of tokenB returned");
        assertEq(pair.balanceOf(user), 0, "User's liquidity token balance should be 0");
    }
    
    function testRemoveLiquidityETH() public {
        // First add ETH liquidity if not already added
        address pairAddress = factory.getPair(TOKEN_A_ADDRESS, WETH_ADDRESS);
        uint256 liquidity;
        
        if (pairAddress == address(0)) {
            tokenA.approve(ROUTER_ADDRESS, INITIAL_AMOUNT);
            
            (,, liquidity) = router.addLiquidityETH{value: 5 ether}(
                TOKEN_A_ADDRESS,
                1000 * 10**18,
                0,
                0,
                user,
                block.timestamp + 3600
            );
            
            pairAddress = factory.getPair(TOKEN_A_ADDRESS, WETH_ADDRESS);
        } else {
            IUniswapV2Pair existingPair = IUniswapV2Pair(pairAddress);
            liquidity = existingPair.balanceOf(user);
            
            // If user doesn't have liquidity, add some
            if (liquidity == 0) {
                tokenA.approve(ROUTER_ADDRESS, INITIAL_AMOUNT);
                
                (,, liquidity) = router.addLiquidityETH{value: 5 ether}(
                    TOKEN_A_ADDRESS,
                    1000 * 10**18,
                    0,
                    0,
                    user,
                    block.timestamp + 3600
                );
            }
        }
        
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        
        // Approve Router to use liquidity tokens
        pair.approve(ROUTER_ADDRESS, liquidity);
        
        uint256 tokenBalanceBefore = tokenA.balanceOf(user);
        uint256 ethBalanceBefore = user.balance;
        
        // Remove liquidity
        (uint256 amountToken, uint256 amountETH) = router.removeLiquidityETH(
            TOKEN_A_ADDRESS,
            liquidity,
            0,
            0,
            user,
            block.timestamp + 3600
        );
        
        uint256 tokenBalanceAfter = tokenA.balanceOf(user);
        uint256 ethBalanceAfter = user.balance;
        
        assertEq(tokenBalanceAfter - tokenBalanceBefore, amountToken, "Incorrect amount of token returned");
        assertEq(ethBalanceAfter - ethBalanceBefore, amountETH, "Incorrect amount of ETH returned");
        assertEq(pair.balanceOf(user), 0, "User's liquidity token balance should be 0");
    }
    
    // 接收ETH的回退函数
    receive() external payable {}
} 