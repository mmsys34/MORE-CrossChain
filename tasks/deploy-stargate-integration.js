const { task } = require("hardhat/config");
const { TASK_COMPILE } = require("hardhat/builtin-tasks/task-names");

task('deploy-stargate-integration', 'Deploy StargateIntegration').setAction(
    async ({}, { ethers, run, network }) => {
        await run(TASK_COMPILE);

        const StargateIntegrationFactory = await ethers.getContractFactory("StargateIntegration");
        const stargateIntegrationFactory = await StargateIntegrationFactory.deploy();
        await stargateIntegrationFactory.waitForDeployment();

        console.log("StargateIntegration deployed to ", stargateIntegrationFactory.target);

        // verify
        if (network.name != "hardhat") {
            await run('verify:verify', {
                address: stargateIntegrationFactory.target
            });

            console.log("StargateIntegration verified");
        }
    }
);
