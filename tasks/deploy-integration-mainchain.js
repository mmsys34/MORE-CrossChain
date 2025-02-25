const { task } = require("hardhat/config");
const { TASK_COMPILE } = require("hardhat/builtin-tasks/task-names");

task('deploy-integration-mainchain', 'Deploy StargateIntegrationMainchain').setAction(
    async ({}, { ethers, run, network }) => {
        await run(TASK_COMPILE);

        if (network.name != "flow" && network.name != "flowTestnet") return;

        const StargateIntegrationFactory = await ethers.getContractFactory("StargateIntegrationMainchain");
        const stargateIntegrationFactory = await StargateIntegrationFactory.deploy();
        await stargateIntegrationFactory.waitForDeployment();

        console.log("StargateIntegrationMainchain deployed to ", stargateIntegrationFactory.target);

        // verify
        await run('verify:verify', {
            address: stargateIntegrationFactory.target
        });

        console.log("StargateIntegrationMainchain verified");
    }
);
