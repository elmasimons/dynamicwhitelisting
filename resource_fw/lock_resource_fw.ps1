param (
    [string]$JsonFile
)

$PublicIp = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content
$Resources = (Get-Content -Raw -Path $JsonFile) | ConvertFrom-Json

foreach ($r in $Resources) {
    [String]$ResourceGroupName = $r.resource_group_name
    [String]$ResourceType = $r.resource_type
    [String]$ResourceName = $r.resource_name

    Write-Host "Removing whitelisting $ResourceGroupName $ResourceType $ResourceName $PublicIp"
    switch ( $ResourceType ) {
        kv {
            Remove-AzKeyVaultNetworkRule -ResourceGroupName $ResourceGroupName -VaultName $ResourceName -IpAddressRange $PublicIp/32 | Out-Null
            Update-AzKeyVaultNetworkRuleSet -ResourceGroupName $ResourceGroupName -VaultName $ResourceName -Bypass AzureServices | Out-Null
            Update-AzKeyVaultNetworkRuleSet -ResourceGroupName $ResourceGroupName -VaultName $ResourceName -DefaultAction Deny | Out-Null
        }
        st {
            Remove-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -Name $ResourceName -IPAddressOrRange $PublicIp | Out-Null
            Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $ResourceGroupName -Name $ResourceName -Bypass AzureServices | Out-Null
            Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $ResourceGroupName -Name $ResourceName -DefaultAction Deny | Out-Null
        }
    }
}