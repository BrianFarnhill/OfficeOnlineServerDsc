<#
.SYNOPSIS

This cmdlet checks if all environment variables are loaded into the PSModulePath
variable.

#>
function Confirm-OosDscEnvironmentVariables
{
    [CmdletBinding()]
    [OutputType()]
    param ()

    $envPSMod = [Environment]::GetEnvironmentVariable("PSModulePath", "Machine") -split ";"
    $curPsMod = $env:PSModulePath -split ";"
    foreach ($path in $envPSMod)
    {
        if ($curPSMod -notcontains $path)
        {
            $env:PSModulePath = $env:PSModulePath + ";$path"
        }
    }
}

<#
.SYNOPSIS

This cmdlet converts a Hashtable into a String

#>
function Convert-OosDscHashtableToString
{
    param
    (
        [Parameter()]
        [System.Collections.Hashtable]
        $Hashtable
    )
    $values = @()
    foreach ($pair in $Hashtable.GetEnumerator())
    {
        if ($pair.Value -is [System.Array])
        {
            $str = "$($pair.Key)=$(Convert-OOSDscArrayToString -Array $pair.Value)"
        }
        elseif ($pair.Value -is [System.Collections.Hashtable])
        {
            $str = "$($pair.Key)={$(Convert-OOSDscHashtableToString -Hashtable $pair.Value)}"
        }
        elseif ($pair.Value -is [Microsoft.Management.Infrastructure.CimInstance])
        {
            $str = "$($pair.Key)=$(Convert-OOSDscCIMInstanceToString -CIMInstance $pair.Value)"
        }
        else
        {
            $str = "$($pair.Key)=$($pair.Value)"
        }
        $values += $str
    }

    [array]::Sort($values)
    return ($values -join "; ")
}

<#
.SYNOPSIS

This cmdlet converts an Array into a String

#>
function Convert-OOSDscArrayToString
{
    param
    (
        [Parameter()]
        [System.Array]
        $Array
    )

    $str = "("
    for ($i = 0; $i -lt $Array.Count; $i++)
    {
        $item = $Array[$i]
        if ($item -is [System.Collections.Hashtable])
        {
            $str += "{"
            $str += Convert-OOSDscHashtableToString -Hashtable $item
            $str += "}"
        }
        elseif ($Array[$i] -is [Microsoft.Management.Infrastructure.CimInstance])
        {
            $str += Convert-OOSDscCIMInstanceToString -CIMInstance $item
        }
        else
        {
            $str += $item
        }

        if ($i -lt ($Array.Count - 1))
        {
            $str += ","
        }
    }
    $str += ")"

    return $str
}

<#
.SYNOPSIS

This cmdlet converts a CIMInstance into a String

#>
function Convert-OOSDscCIMInstanceToString
{
    param
    (
        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $CIMInstance
    )

    $str = "{"
    foreach ($prop in $CIMInstance.CimInstanceProperties)
    {
        if ($str -notmatch "{$")
        {
            $str += "; "
        }
        $str += "$($prop.Name)=$($prop.Value)"
    }
    $str += "}"

    return $str
}

<#
    .SYNOPSIS
        Retrieves the localized string data based on the machine's culture.
        Falls back to en-US strings if the machine's culture is not supported.
    .PARAMETER ResourceName
        The name of the resource as it appears before '.strings.psd1' of the localized string file.
        For example:
            For WindowsOptionalFeature: MSFT_WindowsOptionalFeature
            For Service: MSFT_ServiceResource
            For Registry: MSFT_RegistryResource
            For Helper: SqlServerDscHelper
    .PARAMETER ScriptRoot
        Optional. The root path where to expect to find the culture folder. This is only needed
        for localization in helper modules. This should not normally be used for resources.
    .NOTES
        To be able to use localization in the helper function, this function must
        be first in the file, before Get-LocalizedData is used by itself to load
        localized data for this helper module (see directly after this function).
#>
function Get-LocalizedData
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ResourceName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ScriptRoot
    )

    if (-not $ScriptRoot)
    {
        $dscResourcesFolder = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'DSCResources'
        $resourceDirectory = Join-Path -Path $dscResourcesFolder -ChildPath $ResourceName
    }
    else
    {
        $resourceDirectory = $ScriptRoot
    }

    $localizedStringFileLocation = Join-Path -Path $resourceDirectory -ChildPath $PSUICulture

    if (-not (Test-Path -Path $localizedStringFileLocation))
    {
        # Fallback to en-US
        $localizedStringFileLocation = Join-Path -Path $resourceDirectory -ChildPath 'en-US'
    }

    Import-LocalizedData `
        -BindingVariable 'localizedData' `
        -FileName "$ResourceName.strings.psd1" `
        -BaseDirectory $localizedStringFileLocation

    return $localizedData
}

<#
.SYNOPSIS

This cmdlet determines the version number of Office Web Apps that is installed locally

#>
function Get-OosDscInstalledProductVersion
{
    [CmdletBinding()]
    [OutputType([Version])]
    param ()

    return Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | `
            Select-Object DisplayName, DisplayVersion | `
                Where-Object {
                $_.DisplayName -eq "Microsoft Office Web Apps Server 2013" -or `
                    $_.DisplayName -eq "Microsoft Office Online Server"
            } | ForEach-Object -Process {
                return [Version]::Parse($_.DisplayVersion)
            } | Select-Object -First 1
}


<#
.SYNOPSIS

This cmdlet delete entries from the ZoneMap table for the specified server.

.PARAMETER ServerName

The name of the server that should be removed to the ZoneMap

#>
function Remove-OosDscZoneMap
{
    [CmdletBinding()]
    [OutputType()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $ServerName
    )

    $zoneMap = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap"

    $escDomainsPath = Join-Path -Path $zoneMap -ChildPath "\EscDomains\$ServerName"
    if (Test-Path -Path $escDomainsPath)
    {
        Remove-Item -Path $escDomainsPath
    }

    $domainsPath = Join-Path -Path $zoneMap -ChildPath "\Domains\$ServerName"
    if (Test-Path -Path $domainsPath)
    {
        Remove-Item -Path $domainsPath
    }
}


<#
.SYNOPSIS

This cmdlet creates new entries in the ZoneMap table for the specified server.
This will make sure the UNC path for the server is trusted when the setup is executed.

.PARAMETER ServerName

The name of the server that should be added to the ZoneMap

#>
function Set-OosDscZoneMap
{
    [CmdletBinding()]
    [OutputType()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $ServerName
    )

    $zoneMap = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap"

    $escDomainsPath = Join-Path -Path $zoneMap -ChildPath "\EscDomains\$ServerName"
    if (-not (Test-Path -Path $escDomainsPath))
    {
        $null = New-Item -Path $escDomainsPath -Force
    }

    if ((Get-ItemProperty -Path $escDomainsPath).File -ne 1)
    {
        Set-ItemProperty -Path $escDomainsPath -Name file -Value 1 -Type DWord
    }

    $domainsPath = Join-Path -Path $zoneMap -ChildPath "\Domains\$ServerName"
    if (-not (Test-Path -Path $domainsPath))
    {
        $null = New-Item -Path $domainsPath -Force
    }

    if ((Get-ItemProperty -Path $domainsPath).File -ne 1)
    {
        Set-ItemProperty -Path $domainsPath -Name file -Value 1 -Type DWord
    }
}


<#
.SYNOPSIS

This cmdlet determines if the OU of the farm matches the OU of the current deployment

.PARAMETER DesiredOU

The name of the OU that the farm should be in

.PARAMETER ExistingOU

The name of the OU that the farm currently is in

#>
function Test-OosDscFarmOu
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $DesiredOU,

        [Parameter(Mandatory = $true)]
        [object]
        $ExistingOU
    )

    if ($DesiredOU -like "LDAP://*")
    {
        $sanitizedFarmOU = $DesiredOU -replace 'LDAP://'
    }
    elseif ($DesiredOU -like "ntds://*")
    {
        throw "FarmOU in ntds:// format is not supported";
    }
    else
    {
        $str = ($DesiredOU -replace '/', '\').Trim('\');
        $splitOu = $str -split '\\'
        [array]::Reverse($splitOu)
        $sanitizedFarmOU = "OU=" + ($splitOu -join ",OU=");
    }

    $adsi = [adsisearcher]'(objectCategory=organizationalUnit)'
    $searchRoot = "," + $adsi.SearchRoot.Path -replace 'LDAP://'

    $adsi.Filter = "distinguishedName=$($sanitizedFarmOU)$searchRoot"
    $ou = $adsi.FindOne()

    if ($ou.path)
    {
        $ldapResult = $ou.path -replace $searchRoot
        Write-Verbose -Message "LDAP search result: $ldapResult"
        Write-Verbose "Current Farm OU: $ExistingOU"
        return ($ldapResult -contains $ExistingOU)
    }
    else
    {
        throw "$DesiredOU not found"
    }
}

<#
.SYNOPSIS

This method is used to compare current and desired values for any DSC resource

.PARAMETER CurrentValues

This is hashtable of the current values that are applied to the resource

.PARAMETER DesiredValues

This is a PSBoundParametersDictionary of the desired values for the resource

.PARAMETER ValuesToCheck

This is a list of which properties in the desired values list should be checkked.
If this is empty then all values in DesiredValues are checked.

#>
function Test-OosDscParameterState()
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true, Position = 1)]
        [HashTable]
        $CurrentValues,

        [Parameter(Mandatory = $true, Position = 2)]
        [Object]
        $DesiredValues,

        [Parameter(Position = 3)]
        [Array]
        $ValuesToCheck
    )

    $returnValue = $true

    if (($DesiredValues.GetType().Name -ne "HashTable") `
            -and ($DesiredValues.GetType().Name -ne "CimInstance") `
            -and ($DesiredValues.GetType().Name -ne "PSBoundParametersDictionary"))
    {
        throw ("Property 'DesiredValues' in Test-OOSDscParameterState must be either a " + `
                "Hashtable or CimInstance. Type detected was $($DesiredValues.GetType().Name)")
    }

    if (($DesiredValues.GetType().Name -eq "CimInstance") -and ($null -eq $ValuesToCheck))
    {
        throw ("If 'DesiredValues' is a Hashtable then property 'ValuesToCheck' must contain " + `
                "a value")
    }

    if (($null -eq $ValuesToCheck) -or ($ValuesToCheck.Count -lt 1))
    {
        $KeyList = $DesiredValues.Keys
    }
    else
    {
        $KeyList = $ValuesToCheck
    }

    $KeyList | ForEach-Object -Process {
        if ($_ -ne "Verbose")
        {
            if (($CurrentValues.ContainsKey($_) -eq $false) `
                    -or ($CurrentValues.$_ -ne $DesiredValues.$_) `
                    -or (($DesiredValues.ContainsKey($_) -eq $true) -and ($DesiredValues.$_.GetType().IsArray)))
            {
                if ($DesiredValues.GetType().Name -eq "HashTable" -or `
                        $DesiredValues.GetType().Name -eq "PSBoundParametersDictionary")
                {
                    $CheckDesiredValue = $DesiredValues.ContainsKey($_)
                }
                else
                {
                    $CheckDesiredValue = Test-OOSDscObjectHasProperty $DesiredValues $_
                }

                if ($CheckDesiredValue)
                {
                    $desiredType = $DesiredValues.$_.GetType()
                    $fieldName = $_
                    if ($desiredType.IsArray -eq $true)
                    {
                        if (($CurrentValues.ContainsKey($fieldName) -eq $false) `
                                -or ($null -eq $CurrentValues.$fieldName))
                        {
                            Write-Verbose -Message ("Expected to find an array value for " + `
                                    "property $fieldName in the current " + `
                                    "values, but it was either not present or " + `
                                    "was null. This has caused the test method " + `
                                    "to return false.")
                            $returnValue = $false
                        }
                        else
                        {
                            $arrayCompare = Compare-Object -ReferenceObject $CurrentValues.$fieldName `
                                -DifferenceObject $DesiredValues.$fieldName
                            if ($null -ne $arrayCompare)
                            {
                                Write-Verbose -Message ("Found an array for property $fieldName " + `
                                        "in the current values, but this array " + `
                                        "does not match the desired state. " + `
                                        "Details of the changes are below.")
                                $arrayCompare | ForEach-Object -Process {
                                    Write-Verbose -Message "$($_.InputObject) - $($_.SideIndicator)"
                                }
                                $returnValue = $false
                            }
                        }
                    }
                    else
                    {
                        switch ($desiredType.Name)
                        {
                            "String"
                            {
                                if ([string]::IsNullOrEmpty($CurrentValues.$fieldName) `
                                        -and [string]::IsNullOrEmpty($DesiredValues.$fieldName))
                                {
                                }
                                else
                                {
                                    Write-Verbose -Message ("String value for property " + `
                                            "$fieldName does not match. " + `
                                            "Current state is " + `
                                            "'$($CurrentValues.$fieldName)' " + `
                                            "and desired state is " + `
                                            "'$($DesiredValues.$fieldName)'")
                                    $returnValue = $false
                                }
                            }
                            "Int32"
                            {
                                if (($DesiredValues.$fieldName -eq 0) `
                                        -and ($null -eq $CurrentValues.$fieldName))
                                {
                                }
                                else
                                {
                                    Write-Verbose -Message ("Int32 value for property " + `
                                            "$fieldName does not match. " + `
                                            "Current state is " + `
                                            "'$($CurrentValues.$fieldName)' " + `
                                            "and desired state is " + `
                                            "'$($DesiredValues.$fieldName)'")
                                    $returnValue = $false
                                }
                            }
                            "Int16"
                            {
                                if (($DesiredValues.$fieldName -eq 0) `
                                        -and ($null -eq $CurrentValues.$fieldName))
                                {
                                }
                                else
                                {
                                    Write-Verbose -Message ("Int16 value for property " + `
                                            "$fieldName does not match. " + `
                                            "Current state is " + `
                                            "'$($CurrentValues.$fieldName)' " + `
                                            "and desired state is " + `
                                            "'$($DesiredValues.$fieldName)'")
                                    $returnValue = $false
                                }
                            }
                            default
                            {
                                Write-Verbose -Message ("Unable to compare property $fieldName " + `
                                        "as the type ($($desiredType.Name)) is " + `
                                        "not handled by the " + `
                                        "Test-OOSDscParameterState cmdlet")
                                $returnValue = $false
                            }
                        }
                    }
                }
            }
        }
    }
    return $returnValue
}

<#
.SYNOPSIS

This method is used to check if an object has a specific property

#>
function Test-OOSDscObjectHasProperty
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true, Position = 1)]
        [Object]
        $Object,

        [Parameter(Mandatory = $true, Position = 2)]
        [String]
        $PropertyName
    )

    if (([bool]($Object.PSobject.Properties.name -contains $PropertyName)) -eq $true)
    {
        if ($null -ne $Object.$PropertyName)
        {
            return $true
        }
    }
    return $false
}

Export-ModuleMember -Function *
