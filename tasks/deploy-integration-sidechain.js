const { task } = require("hardhat/config");
const { TASK_COMPILE } = require("hardhat/builtin-tasks/task-names");

task('deploy-integration-sidechain', 'Deploy StargateIntegrationSidechain')
    .addParam('stgIntegrationMainchain', 'StargateIntegrationSidechain address', '', types.string)
    .setAction(
        async ({ stgIntegrationMainchain }, { ethers, run, network }) => {
            await run(TASK_COMPILE);

            if (network.name == "flow" || network.name == "flowTestnet") {
                console.log("Should be deployed on other chains")
                return;
            }
            if (stgIntegrationMainchain == "") {
                console.log("Invalid argument");
                return;
            }

            const StargateIntegrationFactory = await ethers.getContractFactory("StargateIntegrationSidechain");
            const stargateIntegrationFactory = await StargateIntegrationFactory.deploy(stgIntegrationMainchain);
            await stargateIntegrationFactory.waitForDeployment();

            console.log("StargateIntegrationSidechain deployed to ", stargateIntegrationFactory.target);

            // verify
            await run('verify:verify', {
                address: stargateIntegrationFactory.target,
                constructorArguments: [stgIntegrationMainchain]
            });

            console.log("StargateIntegrationSidechain verified");
        }
    );
