const { task } = require("hardhat/config");
const { TASK_COMPILE } = require("hardhat/builtin-tasks/task-names");

task('deploy-adapter-mainchain', 'Deploy DebridgeAdapterMainchain')
    .addParam('dlnSource', 'Used to place orders on DLN', '', types.string)
    .addParam('dlnExternalCallAdapter', 'Intermediary store and the engine for DLN Hooks', '', types.string)
    .setAction(
        async ({ dlnSource, dlnExternalCallAdapter }, { ethers, run, network, upgrades }) => {
            await run(TASK_COMPILE);

            if (network.name != "flow" && network.name != "flowTestnet") return;

            const DebridgeAdapterMainchain = await ethers.getContractFactory("DebridgeAdapterMainchain");
            const debridgeAdapterMainchain = await upgrades.deployProxy(DebridgeAdapterMainchain, [dlnSource, dlnExternalCallAdapter]);
            await debridgeAdapterMainchain.waitForDeployment();

            console.log("DebridgeAdapterMainchain deployed to ", await debridgeAdapterMainchain.getAddress());

            // verify
            await run('verify:verify', {
                address: await debridgeAdapterMainchain.getAddress()
            });

            console.log("DebridgeAdapterMainchain verified");
        }
    );
