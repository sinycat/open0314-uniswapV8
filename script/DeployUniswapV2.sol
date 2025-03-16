// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../src/UniswapV2Factory.sol";
import "../src/UniswapV2Router.sol";
import "../src/WETH9.sol";
import "../src/MyERC20Token.sol";

contract DeployUniswapV2 is Script {
    // Step 1: Deploy tokens and factory
    function deployFactory() external {
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 ;
        vm.startBroadcast(deployerPrivateKey);

        // Deploy WETH9
        WETH9 weth = new WETH9();
        console.log("WETH9 deployed successfully, address:", address(weth));

        // Deploy two ERC20 tokens
        MyERC20Token tokenA = new MyERC20Token("Token A", "TKNA");
        MyERC20Token tokenB = new MyERC20Token("Token B", "TKNB");
        console.log("Token A deployed successfully, address:", address(tokenA));
        console.log("Token B deployed successfully, address:", address(tokenB));

        // Mint some tokens for testing
        tokenA.mint(msg.sender, 1000000 * 10**18);
        tokenB.mint(msg.sender, 1000000 * 10**18);
        console.log("Tokens minted successfully");

        // Deploy UniswapV2Factory
        address feeTo = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Set to zero address, meaning no fee recipient
        UniswapV2Factory factory = new UniswapV2Factory(feeTo);
        console.log("UniswapV2Factory deployed successfully, address:", address(factory));

        // Get INIT_CODE_PAIR_HASH
        bytes32 INIT_CODE_PAIR_HASH = factory.PAIR_HASH();
        console.log("INIT_CODE_PAIR_HASH:", vm.toString(INIT_CODE_PAIR_HASH));
        console.log("Please replace this hash value in UniswapV2Library.sol line 37");
        console.log("Then run the deployRouter function with the factory and WETH addresses");

        vm.stopBroadcast();
    }

    // Step 2: Deploy router after updating the hash
    function deployRouter(address factory, address weth) external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 ;
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy UniswapV2Router
        UniswapV2Router router = new UniswapV2Router(factory, weth);
        console.log("UniswapV2Router deployed successfully, address:", address(router));

        vm.stopBroadcast();
    }
} 