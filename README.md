# Overview
This asset contains bash & powershell scripts to dynamically whitelist the azure devops agent machines on azure resources like key vaults and storage accounts. The resource types that are currently supported by these scripts are Azure Key Vault and Azure Storage account. However you can extend the scripts functionality to add more resource types will need similar whitelisting of ips dynamically.

# Scenarios
When Azure resources are secured using private networks, microsoft based devops agent/runner machines will also be restricted. These scripts should be invoked before and after the secured resources are accessed by the pipelines in order to whitelist the current devops runner during processing and remove the whitelisting once done.

e.g. pipeline needs to access secrets/keys from AKV which is restricted to public:
We are dynamically whitelisting the runner's ip address whenever the pipelines run and once processing is completed we remove the whitelisted ip, by doing this we are able to maintain the integrity and retain the secure access of the key vault on azure.

_Sample DevOps pipelines are also included in this folder_

1. [azure-pipelines](azure-pipelines.yml)
2. [github-actions](github-actions.yml)

# How to use

Please follow the instructions [here](resource_fw/README.md)

