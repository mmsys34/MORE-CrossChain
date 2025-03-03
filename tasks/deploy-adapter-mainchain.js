const { task } = require("hardhat/config");
const { TASK_COMPILE } = require("hardhat/builtin-tasks/task-names");
// const { upgrades } = require("hardhat");

task('deploy-adapter-mainchain', 'Deploy StargateAdapterMainchain')
    .addParam('lzEndpoint', 'LayerZero Endpoint V2 on the Flow chain', '', types.string)
    .setAction(
        async ({ lzEndpoint }, { ethers, run, network, upgrades }) => {
            await run(TASK_COMPILE);

            if (network.name != "flow" && network.name != "flowTestnet") return;

            const StargateAdapterMainchain = await ethers.getContractFactory("StargateAdapterMainchain");
            const stargateAdapterMainchain = await upgrades.deployProxy(StargateAdapterMainchain, [lzEndpoint]);
            await stargateAdapterMainchain.waitForDeployment();

            console.log("StargateAdapterMainchain deployed to ", await stargateAdapterMainchain.getAddress());

            // verify
            await run('verify:verify', {
                address: await stargateAdapterMainchain.getAddress()
            });

            console.log("StargateAdapterMainchain verified");
        }
    );
