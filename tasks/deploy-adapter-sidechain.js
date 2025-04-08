const { task } = require("hardhat/config");
const { TASK_COMPILE } = require("hardhat/builtin-tasks/task-names");

task('deploy-adapter-sidechain', 'Deploy DebridgeAdapterSidechain')
    .addParam('dlnSource', 'Used to place orders on DLN', '', types.string)
    .addParam('debridgeAdapterMainchain', 'The address of DebridgeAdapterMainchain', '', types.string)
    .setAction(
        async ({ dlnSource, debridgeAdapterMainchain }, { ethers, run, network, upgrades }) => {
            await run(TASK_COMPILE);

            if (network.name == "flow" || network.name == "flowTestnet") {
                console.log("Should be deployed on other chains")
                return;
            }

            if (debridgeAdapterMainchain == "") {
                console.log("Invalid argument");
                return;
            }

            const DebridgeAdapterSidechain = await ethers.getContractFactory("DebridgeAdapterSidechain");
            const debridgeAdapterSidechain = await upgrades.deployProxy(DebridgeAdapterSidechain, [dlnSource, debridgeAdapterMainchain]);
            await debridgeAdapterSidechain.waitForDeployment();

            console.log("DebridgeAdapterSidechain deployed to ", await debridgeAdapterSidechain.getAddress());

            // verify
            await run('verify:verify', {
                address: await debridgeAdapterSidechain.getAddress()
            });

            console.log("DebridgeAdapterSidechain verified");
        }
    );
