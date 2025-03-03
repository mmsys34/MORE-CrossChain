const { task } = require("hardhat/config");
const { TASK_COMPILE } = require("hardhat/builtin-tasks/task-names");

task('deploy-adapter-sidechain', 'Deploy StargateAdapterSidechain')
    .addParam('stgAdapterMainchain', 'StargateAdapterMainchain address', '', types.string)
    .setAction(
        async ({ stgAdapterMainchain }, { ethers, run, network, upgrades }) => {
            await run(TASK_COMPILE);

            if (network.name == "flow" || network.name == "flowTestnet") {
                console.log("Should be deployed on other chains")
                return;
            }

            if (stgAdapterMainchain == "") {
                console.log("Invalid argument");
                return;
            }

            const StargateAdapterSidechain = await ethers.getContractFactory("StargateAdapterSidechain");
            const stargateAdapterSidechain = await upgrades.deployProxy(StargateAdapterSidechain, [stgAdapterMainchain]);
            await stargateAdapterSidechain.waitForDeployment();

            console.log("StargateAdapterSidechain deployed to ", await stargateAdapterSidechain.getAddress());

            // verify
            await run('verify:verify', {
                address: await stargateAdapterSidechain.getAddress()
            });

            console.log("StargateAdapterSidechain verified");
        }
    );
