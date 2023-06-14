param (
    [string]$JsonFile,
    [int]$VerifyInterval = 5,
    [int]$VerifyRetryCount = 12
)

function VerifyWhitelist{
    param(
        [Parameter (Mandatory = $true)] [string]$ResourceGroupName,
        [Parameter (Mandatory = $true)] [string]$ResourceType,
        [Parameter (Mandatory = $true)] [string]$ResourceName,
        [Parameter (Mandatory = $true)] [string]$PublicIp
    )

    $n = 0
    While($n -lt $VerifyRetryCount) {
        Start-Sleep -Seconds $VerifyInterval

        Write-Host "$n Verifying whitelisting $ResourceGroupName $ResourceType $ResourceName $PublicIp"

        switch ( $ResourceType ) {
            kv {
                $Resource = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -Name $ResourceName
                if($Resource.NetworkAcls.IpAddressRanges.Contains("$PublicIp/32")) {
                    Write-Host "Whitelisted $ResourceGroupName $ResourceType $ResourceName $PublicIp"
                    Write-Host $Resource.NetworkAcls.IpAddressRanges
                    return
                }
            }
            st {
                $Resource = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $ResourceName
                Foreach ($IpRule in $Resource.NetworkruleSet.IpRules) {
                    If (($IpRule.Action -eq "Allow") -and ($IpRule.IPAddressOrRange -eq $PublicIp)) {
                        Write-Host "Whitelisted $ResourceGroupName $ResourceType $ResourceName $PublicIp"
                        Write-Host $IpRule.IPAddressOrRange
                        return
                    }
                }
            }
        }
        $n++
    } 

    If($n -ge $VerifyRetryCount) {
        Throw "Not whitelisted $ResourceGroupName $ResourceType $ResourceName $PublicIp"
    }
}

function Whitelist{
    param(
        [Parameter (Mandatory = $true)] [string]$ResourceGroupName,
        [Parameter (Mandatory = $true)] [string]$ResourceType,
        [Parameter (Mandatory = $true)] [string]$ResourceName,
        [Parameter (Mandatory = $true)] [string]$PublicIp
    )

    Write-Host "Whitelisting $ResourceGroupName $ResourceType $ResourceName $PublicIp"

    switch ( $ResourceType ) {
        kv {
            Add-AzKeyVaultNetworkRule -ResourceGroupName $ResourceGroupName -VaultName $ResourceName -IpAddressRange $PublicIp/32 | Out-Null
            Update-AzKeyVaultNetworkRuleSet -ResourceGroupName $ResourceGroupName -VaultName $ResourceName -Bypass AzureServices | Out-Null
            Update-AzKeyVaultNetworkRuleSet -ResourceGroupName $ResourceGroupName -VaultName $ResourceName -DefaultAction Deny | Out-Null

            VerifyWhitelist $ResourceGroupName $ResourceType $ResourceName $PublicIp

        }
        st {
            Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -Name $ResourceName -IPAddressOrRange $PublicIp | Out-Null
            Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $ResourceGroupName -Name $ResourceName -Bypass AzureServices | Out-Null
            Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $ResourceGroupName -Name $ResourceName -DefaultAction Deny | Out-Null

            VerifyWhitelist $ResourceGroupName $ResourceType $ResourceName $PublicIp
        }
    }
}

function main () {
    [String]$PublicIp = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content
    $Resources = (Get-Content -Raw -Path $JsonFile) | ConvertFrom-Json

    foreach ($r in $Resources) {
        [String]$ResourceGroupName = $r.resource_group_name
        [String]$ResourceType = $r.resource_type
        [String]$ResourceName = $r.resource_name

        Whitelist $ResourceGroupName $ResourceType $ResourceName $PublicIp
    }
}

main