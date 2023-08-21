function Format-Column
{
<#
.SYNOPSIS
 Format-Column formats object data as columns, ordering data column by column as default.
 
.DESCRIPTION
 Format-Column function outputs object data into columns, similarly to built-in cmdlet Format-Wide.
 It can order output data column by column in addition to row by row,
 as is the only option in Format-Wide.
 
.PARAMETER Property
 Name of object property to be displayed.
 
 The value of the Property parameter can also be a calculated property:
 - a hash table. Valid syntaxes are:
     - @{Expression=<string>|{<scriptblock>}}
     - @{FormatString=<string>}
     - @{Expression=<string>|{<scriptblock>}; FormatString=<string>}
     
 - a script block: {<scriptblock>}
 
 Property parameter is optional. However, if omitted for data containing properties,
 but missing DefaultDisplayProperty, no comprehensible data output will be produced.
 
.PARAMETER ColumnCount
 Number of columns to display (CustomSize mode). If ColumnCount parameter is omitted the number
 of columns is calculated automatically (AutoSize mode).
 
.PARAMETER MaxColumnCount
 Maximum number of columns to display in AutoSize mode. Optional.
 Cannot be combined with ColumnCount parameter.
 
.PARAMETER MinRowCount
 Minimum number of rows to display in AutoSize mode. Optional.
 Cannot be combined with ColumnCount parameter.
 
.PARAMETER GroupBy
 Formats the output in groups based on a shared property or value. Optional.
 Can be the name of a property or an expression (hash table or script block):
 - a hash table. Valid syntaxes are:
     - @{Expression=<string>|{<scriptblock>}}
     - @{Label/Name=<string>; Expression=<string>|{<scriptblock>}}
     - @{Label/Name=<string>; Expression=<string>|{<scriptblock>}; FormatString=<string>}
 
 - a script block: {<scriptblock>}
 
.PARAMETER OrderBy
 Determines data order in column output. Default value is Column.
 
 Valid values are:
 - Column: Orders data column by column.
 - Row: Orders data row by row.
 
.PARAMETER InputObject
 Object to format for display. Accepts pipeline input.
 
.EXAMPLE
 1..100 | Format-Column -MinRowCount 20 -OrderBy Row
 
.EXAMPLE
 Format-Column -Property @{FormatString='{0:000}'} -ColumnCount 3 -InputObject @(1..125)
 
.EXAMPLE
 Get-Process | Format-Column -Property @{Expr='Id'; FormatStr='{0:00000}'}
 
.EXAMPLE
 # The following Property syntaxes are all equivalent:
 
 Get-Process | Format-Column -Property ProcessName              # name (string)
 Get-Process | Format-Column -Property {$_.ProcessName}         # scriptblock
 Get-Process | Format-Column -Property @{Expr='ProcessName'}    # hashtable string expression
 Get-Process | Format-Column -Property @{Expr={$_.ProcessName}} # hashtable scriptblock expression
 
.INPUTS
 You can pipe any object to Format-Column.
 
.OUTPUTS
 Format-Column returns strings that represent the output table.
 
.NOTES
 Included alias for Format-Column is 'fcol'.
 
.LINK
 Online version: https://github.com/loxia01/FormatColumn
#>
    [CmdletBinding(DefaultParameterSetName='AutoSize')]
    [Alias('fcol')]
    param (
        [Parameter(Position=0)]
        [Object]$Property,
        
        [Parameter(ParameterSetName='CustomSize', Mandatory)]
        [ValidateScript({$_ -gt 0})]
        [int]$ColumnCount,
        
        [Parameter(ParameterSetName='AutoSize')]
        [ValidateScript({$_ -gt 0})]
        [int]$MaxColumnCount,
        
        [Parameter(ParameterSetName='AutoSize')]
        [ValidateScript({$_ -gt 0})]
        [int]$MinRowCount,
        
        [Parameter()]
        [Object]$GroupBy,
        
        [Parameter()]
        [ValidateSet('Column','Row')]
        [string]$OrderBy = 'Column',
        
        [Parameter(ValueFromPipeline)]
        [Object]$InputObject
    )
    if ($input) { $InputObject = $input }
    
    if ($null -ne $InputObject) { $inputData = $InputObject }
    else { return }
    
    if ($null -ne $GroupBy)
    {
        # GroupBy parameter validation and processing
        if ($GroupBy -is [hashtable])
        {
            $GroupBy.Keys | ForEach-Object {
                if     ($_ -match '^(na?m?e?|la?b?e?l?)$')     { $label = $GroupBy.$_ }
                elseif ($_ -match '^ex?p?r?e?s?s?i?o?n?$')     { $expr = $GroupBy.$_ }
                elseif ($_ -match '^fo?r?m?a?t?s?t?r?i?n?g?$') { $formatStr = $GroupBy.$_ }
                else { Write-Error "Invalid GroupBy hash table key '${_}'." -Category 5 -EA 1 }
            }
            if ($expr)
            {
                if ($label)
                {
                    if ($label -isnot [string]) { Write-Error "Invalid GroupBy name/label type." -Category 5 -EA 1 }
                    $groupLabel = $label
                }
                if ($formatStr) { if ($formatStr -isnot [string]) { Write-Error "Invalid GroupBy formatstring type." -Category 5 -EA 1 } }
                
                if ($expr -is [string])
                {
                    if ($formatStr) { $sb = { $formatStr -f $_.$expr } }
                    else            { $sb = { $_.$expr } }
                    
                    $filterSB = [scriptblock]::Create("([string](${sb})) -eq `$grVal")
                    foreach ($grVal in (($inputData | Group-Object $sb).Name | Sort-Object))
                    {
                        New-Variable -Name ("inputData_" + "{0:00}" -f $i) -Value $inputData.Where($filterSB)
                        New-Variable -Name ("groupValue_" + "{0:00}" -f $i++) -Value $grVal
                    }
                    trap { Write-Error "GroupBy formatstring processing error." -Category 5 -EA 1 }
                    
                    if (-not $label)
                    {
                        if (-not ($groupLabel = $inputData[0].PSObject.Properties.Name.Where({$_ -eq $expr}))) { $groupLabel = $expr }
                    }
                }
                elseif ($expr -is [scriptblock])
                {
                    if ($formatStr) { $sb = [scriptblock]::Create("'${formatStr}' -f $expr") }
                    else            { $sb = $expr }
                    
                    $filterSB = [scriptblock]::Create("([string](${sb})) -eq `$grVal")
                    foreach ($grVal in (($inputData | Group-Object $sb).Name | Sort-Object))
                    {
                        New-Variable -Name ("inputData_" + "{0:00}" -f $i) -Value $inputData.Where($filterSB)
                        New-Variable -Name ("groupValue_" + "{0:00}" -f $i++) -Value $grVal
                    }
                    trap { Write-Error "GroupBy processing error." -Category 5 -EA 1 }
                    
                    if (-not $label) { $groupLabel = $expr }
                }
                else { Write-Error "Invalid GroupBy expression type." -Category 5 -EA 1 }
            }
            else { Write-Error "GroupBy hash table is missing mandatory expression entry." -Category 5 -EA 1 }
        }
        elseif ($GroupBy -is [scriptblock])
        {
            $filterSB = [scriptblock]::Create("([string](${GroupBy})) -eq `$grVal")
            foreach ($grVal in (($inputData | Group-Object $GroupBy).Name | Sort-Object))
            {
                New-Variable -Name ("inputData_" + "{0:00}" -f $i) -Value $inputData.Where($filterSB)
                New-Variable -Name ("groupValue_" + "{0:00}" -f $i++) -Value $grVal
            }
            trap { Write-Error "GroupBy processing error." -Category 5 -EA 1 }
            
            $groupLabel = $GroupBy
        }
        elseif ($GroupBy -is [string])
        {
            foreach ($grVal in (($inputData | Group-Object $GroupBy).Name | Sort-Object))
            {
                New-Variable -Name ("inputData_" + "{0:00}" -f $i) -Value $inputData.Where({[string]$_.$GroupBy -eq $grVal})
                New-Variable -Name ("groupValue_" + "{0:00}" -f $i++) -Value $grVal
            }
            if (-not ($groupLabel = $inputData[0].PSObject.Properties.Name.Where({$_ -eq $GroupBy}))) { $groupLabel = $GroupBy }
        }
        else { Write-Error "Invalid GroupBy type." -Category 5 -EA 1 }
        
        $expr = $formatStr = $null
        if ($inputDataVbs = Get-Variable -Name inputData_*)
        {
            Remove-Variable inputData
            $groupValueVbs = Get-Variable -Name groupValue_*
            
            # Property parameter validation and processing
            if ($null -ne $Property)
            {
                if ($Property -is [hashtable])
                {
                    $Property.Keys | ForEach-Object {
                        if     ($_ -match '^ex?p?r?e?s?s?i?o?n?$')     { $expr = $Property.$_ }
                        elseif ($_ -match '^fo?r?m?a?t?s?t?r?i?n?g?$') { $formatStr = $Property.$_ }
                        else { Write-Error "Invalid Property key '${_}'." -Category 5 -EA 1 }
                    }
                    if ($expr)
                    {
                        if ($expr -is [string])
                        {
                            $inputDataVbs | ForEach-Object { Set-Variable $_.Name -Value ($_.Value | ForEach-Object { $_.$expr }) }
                        }
                        elseif ($expr -is [scriptblock])
                        {
                            $inputDataVbs | ForEach-Object { Set-Variable $_.Name -Value ($_.Value | ForEach-Object $expr) }
                            trap { Write-Error "Property expression processing error." -Category 5 -EA 1 }
                        }
                        else { Write-Error "Invalid Property expression type." -Category 5 -EA 1 }
                    }
                    if ($formatStr)
                    {
                        if ($formatStr -is [string])
                        {
                            $inputDataVbs | ForEach-Object { Set-Variable $_.Name -Value ($_.Value | ForEach-Object { $formatStr -f $_ }) }
                            trap { Write-Error "Property processing error." -Category 5 -EA 1 }
                        }
                        else { Write-Error "Invalid Property formatstring type." -Category 5 -EA 1 }
                    }
                }
                elseif ($Property -is [scriptblock])
                {
                    $inputDataVbs | ForEach-Object { Set-Variable $_.Name -Value ($_.Value | ForEach-Object $Property) }
                    trap { Write-Error "Property processing error." -Category 5 -EA 1 }
                }
                elseif ($Property -is [string])
                {
                    $inputDataVbs | ForEach-Object { Set-Variable $_.Name -Value ($_.Value | ForEach-Object { $_.$Property }) }
                }
                else { Write-Error "Invalid Property type." -Category 5 -EA 1 }
            }
            else
            {
                if ($InputObject.PSStandardMembers)
                {
                    if ($InputObject.PSStandardMembers.DefaultDisplayPropertySet -ne $null)
                    {
                        $defaultDisplayProperty = $InputObject.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames[-1]
                    }
                    elseif ($InputObject.PSStandardMembers.DefaultDisplayProperty -ne $null)
                    {
                        $defaultDisplayProperty = $InputObject.PSStandardMembers.DefaultDisplayProperty[-1]
                    }
                    else { $defaultDisplayProperty = $null }
                    
                    if ($defaultDisplayProperty)
                    {
                        $inputDataVbs | ForEach-Object { Set-Variable $_.Name -Value ($_.Value | ForEach-Object { $_.$defaultDisplayProperty }) }
                    }
                }
            }
            
            # Conversion to string array
            $inputDataVbs | ForEach-Object { Set-Variable $_.Name -Value ($_.Value | ForEach-Object { [string]$_ }) }
            
            # Output Processing
            
            $consoleWidth = $Host.UI.RawUI.WindowSize.Width
            $columnGap = 1
            
            if (-not $ColumnCount)
            {
                $ColumnCount = ($inputDataVbs | ForEach-Object {
                    $maxLength = ($_.Value | Measure-Object Length -Maximum).Maximum
                
                    $colCount = [Math]::Max(1, [Math]::Floor($consoleWidth / ($maxLength + $columnGap)))
                    if ($MaxColumnCount -and $MaxColumnCount -lt $colCount) { $MaxColumnCount }
                    else                                                    { $colCount }
                } | Measure-Object -Minimum).Minimum
            }
            
            foreach ($inputDataVb in $inputDataVbs)
            {
                $rowCount = [Math]::Ceiling($inputDataVb.Value.Count / $ColumnCount)
                
                if ($MinRowCount -and $MinRowCount -gt $rowCount)
                {
                    $ColumnCount = [Math]::Max(1, [Math]::Floor($inputDataVb.Value.Count / $MinRowCount))
                    $rowCount = [Math]::Ceiling($inputDataVb.Value.Count / $ColumnCount)
                }
                
                $maxLength = ($inputDataVb.Value | Measure-Object Length -Maximum).Maximum
                $columnWidth = [Math]::Floor(($consoleWidth - $ColumnCount * $columnGap) / $ColumnCount)
                
                <# Truncate strings longer than column width (applicable only for CustomSize mode, or in
                   AutoSize mode if string lengths greater than or equal to console width are present). #>
                if ($maxLength -gt $columnWidth)
                {
                    if ($columnWidth -ge 3)
                    {
                        $inputDataVb.Value = $inputDataVb.Value | ForEach-Object {
                            if ($_.Length -gt $columnWidth) { $_.Remove($columnWidth - 3) + "..." }
                            else                            { $_ }
                        }
                    }
                    # Write terminating error if column width is too small for truncate ellipsis "..."
                    else { Write-Error "ColumnCount value too large for output display." -Category 5 -EA 1 }
                }
                
                # Create format string for output
                $alignment = -($columnWidth + $columnGap)
                $formatString = (
                    0..($ColumnCount - 1) | ForEach-Object {
                        "{${_},${alignment}}"
                    }
                ) -join ""
                
                # Output data ordered column by column or row by row, adding empty line(s) before and after.
                
                # Output group label and value
                if ($PSEdition -eq 'Desktop') { Write-Output "" }
                Write-Output "`n   ${groupLabel}: $($groupValueVbs[$j++].Value)`n"
                if ($PSEdition -eq 'Desktop') { Write-Output "" }
                
                0..($rowCount - 1) | ForEach-Object {
                    $row = $_
                    $lineContent = 0..($ColumnCount - 1) | ForEach-Object {
                        $column = $_
                        if ($OrderBy -eq 'Column') { @($inputDataVb.Value)[$row + $column * $rowCount] }
                        else                       { @($inputDataVb.Value)[$column + $row * $ColumnCount] }
                    }
                    Write-Output ($formatString -f $lineContent)
                }
                if ($inputDataVb.Name -eq @($inputDataVbs.Name)[-1])
                {
                    if ($PSEdition -eq 'Desktop') { Write-Output "`n" }
                    else                          { Write-Output "" }
                }
            }
        }
    }
    if ($null -eq $GroupBy -or $inputData)
    {
        # Property parameter validation and processing
        if ($null -ne $Property)
        {
            if ($Property -is [hashtable])
            {
                $Property.Keys | ForEach-Object {
                    if     ($_ -match '^ex?p?r?e?s?s?i?o?n?$')     { $expr = $Property.$_ }
                    elseif ($_ -match '^fo?r?m?a?t?s?t?r?i?n?g?$') { $formatStr = $Property.$_ }
                    else { Write-Error "Invalid Property key '${_}'." -Category 5 -EA 1 }
                }
                if ($expr)
                {
                    if ($expr -is [string])
                    {
                        $inputData = $inputData | ForEach-Object { $_.$expr }
                    }
                    elseif ($expr -is [scriptblock])
                    {
                        $inputData = $inputData | ForEach-Object $expr
                        trap { Write-Error "Property expression processing error." -Category 5 -EA 1 }
                    }
                    else { Write-Error "Invalid Property expression type." -Category 5 -EA 1 }
                }
                if ($formatStr)
                {
                    if ($formatStr -is [string])
                    {
                        $inputData = $inputData | ForEach-Object { $formatStr -f $_ }
                        trap { Write-Error "Property processing error." -Category 5 -EA 1 }
                    }
                    else { Write-Error "Invalid Property formatstring type." -Category 5 -EA 1 }
                }
            }
            elseif ($Property -is [scriptblock])
            {
                $inputData = $inputData | ForEach-Object $Property
                trap { Write-Error "Property processing error." -Category 5 -EA 1 }
            }
            elseif ($Property -is [string])
            {
                $inputData = $inputData | ForEach-Object { $_.$Property }
            }
            else { Write-Error "Invalid Property type." -Category 5 -EA 1 }
        }
        else
        {
            if ($InputObject.PSStandardMembers)
            {
                if ($InputObject.PSStandardMembers.DefaultDisplayPropertySet -ne $null)
                {
                    $defaultDisplayProperty = $InputObject.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames[-1]
                }
                elseif ($InputObject.PSStandardMembers.DefaultDisplayProperty -ne $null)
                {
                    $defaultDisplayProperty = $InputObject.PSStandardMembers.DefaultDisplayProperty[-1]
                }
                else { $defaultDisplayProperty = $null }
                
                if ($defaultDisplayProperty)
                {
                    $inputData = $inputData | ForEach-Object { $_.$defaultDisplayProperty }
                }
            }
        }
        
        # Conversion to string array
        $inputData = $inputData | ForEach-Object { [string]$_ }
        
        # Output Processing
    
        $consoleWidth = $Host.UI.RawUI.WindowSize.Width
        $columnGap = 1
        
        $maxLength = ($inputData | Measure-Object Length -Maximum).Maximum
        
        if (-not $ColumnCount)
        {
            $ColumnCount = [Math]::Max(1, [Math]::Floor($consoleWidth / ($maxLength + $columnGap)))
            if ($_.Value.Count -lt $colCount) { $ColumnCount = $inputData.Count }
            if ($MaxColumnCount -and $MaxColumnCount -lt $ColumnCount) { $ColumnCount = $MaxColumnCount }
        }
        
        $rowCount = [Math]::Ceiling($inputData.Count / $ColumnCount)
        
        if ($MinRowCount -and $MinRowCount -gt $rowCount)
        {
            $ColumnCount = [Math]::Max(1, [Math]::Floor($inputData.Count / $MinRowCount))
            $rowCount = [Math]::Ceiling($inputData.Count / $ColumnCount)
        }
        
        $columnWidth = [Math]::Floor(($consoleWidth - $ColumnCount * $columnGap) / $ColumnCount)
        
        <# Truncate strings longer than column width (applicable only for CustomSize mode, or in
           AutoSize mode if string lengths greater than or equal to console width are present). #>
        if ($maxLength -gt $columnWidth)
        {
            if ($columnWidth -ge 3)
            {
                $inputData = $inputData | ForEach-Object {
                    if ($_.Length -gt $columnWidth) { $_.Remove($columnWidth - 3) + "..." }
                    else                            { $_ }
                }
            }
            # Write terminating error if column width is too small for truncate ellipsis "..."
            else { Write-Error "ColumnCount value too large for output display." -Category 5 -EA 1 }
        }
        
        # Create format string for output
        $alignment = -($columnWidth + $columnGap)
        $formatString = (
            0..($ColumnCount - 1) | ForEach-Object {
                "{${_},${alignment}}"
            }
        ) -join ""
        
        # Output data ordered column by column or row by row, adding blank line(s) before and after
        
        if ($PSEdition -eq 'Desktop') { Write-Output "`n" }
        else                          { Write-Output "" }
        0..($rowCount - 1) | ForEach-Object {
            $row = $_
            $lineContent = 0..($ColumnCount - 1) | ForEach-Object {
                $column = $_
                if ($OrderBy -eq 'Column') { @($inputData)[$row + $column * $rowCount] }
                else                       { @($inputData)[$column + $row * $ColumnCount] }
            }
            Write-Output ($formatString -f $lineContent)
        }
        if ($PSEdition -eq 'Desktop') { Write-Output "`n" }
        else                          { Write-Output "" }
    }
}
