// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;

interface IKittyRouterNgPoolsOnly {
    /**
     * @notice Performs up to 5 swaps in a single transaction.
     * @dev Routing and swap params must be determined off-chain. This
     * functionality is designed for gas efficiency over ease-of-use.
     * @param route Array of [initial token, pool, token, pool, token, ...]
     * The array is iterated until a pool address of 0x00, then the last
     * given token is transferred to `_receiver`
     * @param swapParams Multidimensional array of [i, j, swap_type, pool_type] where
     * i is the index of input token
     * j is the index of output token

     * The swap_type should be:
     * 1. for `exchange`,
     * 2. for `exchange_underlying` (stable-ng metapools),
     * 3. -- legacy --
     * 4. for coin -> LP token "exchange" (actually `add_liquidity`),
     * 5. -- legacy --
     * 6. for LP token -> coin "exchange" (actually `remove_liquidity_one_coin`)
     * 7. -- legacy --
     * 8. for ETH <-> WETH

     * pool_type: 10 - stable-ng, 20 - twocrypto-ng, 30 - tricrypto-ng, 4 - llamma

     * @param amountIn The amount of input token (`route[0]`) to be sent.
     * @param minDY The minimum amount received after the final swap.
     * @param receiver Address to transfer the final output token to.
     * @return Received amount of the final output token.
     */
    function exchange(
        address[11] calldata route,
        uint256[4][5] calldata swapParams,
        uint256 amountIn,
        uint256 minDY,
        address receiver
    ) external returns (uint256);
}
