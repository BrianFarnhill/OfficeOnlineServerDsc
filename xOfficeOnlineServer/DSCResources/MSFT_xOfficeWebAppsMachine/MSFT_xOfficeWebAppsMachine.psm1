﻿data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData -StringData @'
NotApartOfAFarm = It does not appear that this machine is part of an Office Online Server farm.
ChangingAppMachineConfig = Changing App Maching Configuration.
SetAppMachine = The Office Web App Machine has been Set.
'@
}

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $MachineToJoin
    )


    Import-Module -Name OfficeWebApps -ErrorAction Stop

    $officeWebAppsMachine = $null

    try
    {
        $officeWebAppsMachine = Get-OfficeWebAppsMachine
    }
    catch
    {
        # catch when not appart of the farm and redirect output to returned hash table
        if($_.toString() -like "It does not appear that this machine is part of an Office Online Server farm.")
        {
            Write-Verbose ( $LocalizedData.NotApartOfAFarm )
        }
        else
        {
            throw
        }
    }

    if($null -eq $officeWebAppsMachine)
    {
        $returnValue = @{
            Ensure = [System.String]"Absent"
            Roles = [System.String[]]""
            MachineToJoin = [System.String]""
        }
    }
    else
    {
        $returnValue = @{
            Ensure = [System.String]"Present"
            Roles = [System.String[]]$officeWebAppsMachine.Roles
            MachineToJoin = [System.String]$officeWebAppsMachine.MasterMachineName
        }
    }

    $returnValue
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.String[]]
        $Roles,

        [parameter(Mandatory = $true)]
        [System.String]
        $MachineToJoin
    )

    Import-Module -Name OfficeWebApps -ErrorAction Stop

    if($Ensure -eq "Absent")
    {
        Remove-OfficeWebAppsMachine
    }
    else
    {
        $officeWebAppsMachine = $null

        If($null -eq $Roles)
        {
            $Roles += "All" 
        }

        try
        {
            $officeWebAppsMachine = Get-OfficeWebAppsMachine

            Write-Verbose ( $LocalizedData.ChangingAppMachineConfig )

            Set-OfficeWebAppsMachine -Master $MachineToJoin -Roles $Roles

            Write-Verbose ( $LocalizedData.SetAppMachine )
        }
        catch
        {
            # catch when not appart of the farm and redirect output to returned hash table
            if($_.toString() -like "It does not appear that this machine is part of an Office Online Server farm.")
            {
                Write-Verbose ( $LocalizedData.NotApartOfAFarm )                

                New-OfficeWebAppsMachine -MachineToJoin $MachineToJoin -Roles $Roles

                Write-Verbose ( $LocalizedData.SetAppMachine )
            }
            else
            {
                throw
            }
        }
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.String[]]
        $Roles,

        [parameter(Mandatory = $true)]
        [System.String]
        $MachineToJoin
    )

    $results = Get-TargetResource -MachineToJoin $MachineToJoin

    If($null -eq $Roles)
    {
        $Roles += "All" 
    }

    if( ($results.Ensure -eq "Present") `
            -and ($Ensure -eq "Present") `
            -and ($results.MachineToJoin -eq $MachineToJoin) `
            -and ( $null -eq (Compare-Object -ReferenceObject $results.Roles -DifferenceObject $Roles ) ) )  # If present and all value match return true
    {
        return $true
    }
    elseif(($results.Ensure -eq "Absent") -and ($Ensure -eq "Absent")) # if absent no need to check all values
    {
         return $true
    }
    else
    {
        return $false
    }
}

Export-ModuleMember -Function *-TargetResource

