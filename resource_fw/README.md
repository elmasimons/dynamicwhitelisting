# Azure Resource Firewall Scripts

- 1. Introducton
- 2. How to Use
  - 2.1 inputs
    - 2.1.1 resourcespath
    - 2.1.2 isshellrequired
    - 2.1.3 islockrequired
  - 2.2 Usage 
- 3. Developers 
 -  3.1 Bash 
  - 3.1.1 Whitelist IP
  - 3.1.2 Undo Whitelist IP
 - 3.2 Powershell
  - 3.2.1 Whitelist IP
  - 3.2.2 Undo Whitelist IP

# 1. Introduction
The scripts and files in this directory enable a developer to whitelist an ip address and remove a whitelisted ip address in Azure resource that support this functionality.

# 2. How to Use for Action Consumers
Create a file resource.<ENVIRONMENT_NAME>.json for each environment. Add resources to "resources.<ENVIRONMENT_NAME>.json" file. For example, for prod environment the file name would be "resource.prod.json". An example "resource.<ENVIRONMENT_NAME>.json" for dev environment is present in this directory (resources.dev.json). The file structure is self-explanatory. For resource keys it is recommended to use resource abbreviations recommended by Azure found at the following link https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations.

Currently only storage account and keyvault are supported in the script. If there is a need to support for other resource please reach out to development team for the update.

Also the Composite action requires three inputs : 
## 2.1 Inputs :
### 2.1.1 resourcesPath : 
Path of the file resource mentioned above, pass the exact path in your repository, Input here is string
## 2.1.2 isShellRequired: 
The scripts have been organized in two different executable formats, Shell & Powershell, it is upto the consumer preference through which they would like to execute, input here is boolean value where true is Shell Execution and false relates to powershell.
## 2.1.3 isLockRequired : 
As we are having Unlock & Lock of Azure Resources, select the operation for respective operation. Input here is boolean value, where true denotes Locking of Azure Resource, false denotes Unlocking.

## 2.2 Usage
```yaml

trigger:
- none

pool:
  vmImage: ubuntu-latest

steps:
- script: echo Hello, world!
  displayName: 'Run a one-line script'

- checkout: self
# Include step to whitelist the secured resources
- task: AzureCLI@2
  inputs:
    azureSubscription: 'hm-tt-sandbox'
    scriptType: 'bash'
    scriptLocation: 'scriptPath'
    scriptPath: 'dynamic-whitelisting-scripts/resource_fw/unlock_resource_fw.sh'
    arguments: '-j resources.dev.json -t 5 -r 2'
    workingDirectory: 'dynamic-whitelisting-scripts/resource_fw/'
    failOnStandardError: true
  displayName: Unlock Resource Firewalls

- task: AzureKeyVault@2
  inputs:
    azureSubscription: 'hm-tt-sandbox'
    KeyVaultName: 'elmtestakv'
    SecretsFilter: '*'
    RunAsPreJob: false

- task: AzureCLI@2
  inputs:
    azureSubscription: 'hm-tt-sandbox'
    scriptType: 'bash'
    scriptLocation: 'scriptPath'
    scriptPath: 'dynamic-whitelisting-scripts/resource_fw/lock_resource_fw.sh'
    arguments: '-j resources.dev.json'
    workingDirectory: 'dynamic-whitelisting-scripts/resource_fw/'
  displayName: Lock Resource Firewalls
  condition: always()

      

```

# 3. Developers :
Developers working on this Directory, please follow the steps prescribed below. PS : Currently the scripts listed only support kv & st(Keyvault & Storage) if there is a need to update this functionality to other Azure Resource please update all bash and powershell scripts accordingly (unlock_resource_fw.sh, lock_resource_fw.sh, unlock_resource_fw.ps1 and lock_resource_fw.ps1)

## 3.1 Bash
### 3.1.1 Whitelist IP
```
unlock_resource_fw.sh --json-file resources.dev.json
```
### 3.1.2 Undo Whitelist IP
```
lock_resource_fw.sh --json-file resources.dev.json
```
## 3.2 Powershell
### 3.2.1 Whitelist IP
```
unlock_resource_fw.ps1 -JsonFile resources.dev.json
```
### 3.2.2 Undo Whitelist IP
```
lock_resource_fw.ps1 -JsonFile resources.dev.json
```
