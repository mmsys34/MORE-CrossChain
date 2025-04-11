const { task } = require("hardhat/config");
const { TASK_COMPILE } = require("hardhat/builtin-tasks/task-names");

task('deploy-adapter-mainchain', 'Deploy DebridgeAdapterMainchain')
    .addParam('dlnSource', 'Used to place orders on DLN', '0xeF4fB24aD0916217251F553c0596F8Edc630EB66', types.string)
    .addParam('dlnExternalCallAdapter', 'Intermediary store and the engine for DLN Hooks', '0xE93356b0b87c71A7F4957DCEBEd05BefA8cB624a', types.string)
    .addParam('punchSwapRouter', 'PunchSwap Router address', '0xf45AFe28fd5519d5f8C1d4787a4D5f724C0eFa4d', types.string)
    .addParam('kittySwapRouter', 'KittySwap Router address', '0x09d35647ceDC6725696E330Be485Ccc0D3385819', types.string)
    .setAction(
        async ({ dlnSource, dlnExternalCallAdapter, punchSwapRouter, kittySwapRouter }, { ethers, run, network, upgrades }) => {
            await run(TASK_COMPILE);

            if (network.name != "flow" && network.name != "flowTestnet") return;

            const DebridgeAdapterMainchain = await ethers.getContractFactory("DebridgeAdapterMainchain");
            const debridgeAdapterMainchain = await upgrades.deployProxy(DebridgeAdapterMainchain, [
                dlnSource,
                dlnExternalCallAdapter,
                punchSwapRouter,
                kittySwapRouter
            ]);
            await debridgeAdapterMainchain.waitForDeployment();

            console.log("DebridgeAdapterMainchain deployed to ", await debridgeAdapterMainchain.getAddress());

            // verify
            await run('verify:verify', {
                address: await debridgeAdapterMainchain.getAddress()
            });

            console.log("DebridgeAdapterMainchain verified");
        }
    );
