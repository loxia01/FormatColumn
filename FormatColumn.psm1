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
    
    # Property and GroupBy validation and processing
    
    if ($Property)
    {
        if ($Property -is [hashtable])
        {
            $Property.Keys | ForEach-Object {
                if     ($_ -match '^ex?p?r?e?s?s?i?o?n?$')     { $pExpr = $Property.$_ }
                elseif ($_ -match '^fo?r?m?a?t?s?t?r?i?n?g?$') { $pFormatStr = $Property.$_ }
                else { Write-Error "Invalid Property key '${_}'." -Category 5 -EA 1 }
            }
            if ($pExpr)
            {
                if ($pFormatStr)
                {
                    if ($pFormatStr -isnot [string]) { Write-Error "Invalid Property formatstring type." -Category 5 -EA 1 }
                    
                    if     ($pExpr -is [string])      { $propertySelect = {$pFormatStr -f $_.$pExpr} }
                    elseif ($pExpr -is [scriptblock]) { $propertySelect = [scriptblock]::Create("'${pFormatStr}' -f $pExpr") }
                    else { Write-Error "Invalid Property expression type." -Category 5 -EA 1 }
                }
                else
                {
                    if     ($pExpr -is [string])      { $propertySelect = {[string]$_.$pExpr} }
                    elseif ($pExpr -is [scriptblock]) { $propertySelect = [scriptblock]::Create("[string]@(${pExpr})") }
                    else { Write-Error "Invalid Property expression type." -Category 5 -EA 1 }
                }
            }
            else { Write-Error "Property hash table is missing mandatory expression entry." -Category 5 -EA 1 }
        }
        elseif ($Property -is [string])      { $propertySelect = {[string]$_.$Property} }
        elseif ($Property -is [scriptblock]) { $propertySelect = [scriptblock]::Create("[string]@(${Property})") }
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
                
            if ($defaultDisplayProperty) { $propertySelect = {[string]$_.$defaultDisplayProperty} }
        }
        else { $propertySelect = {[string]$_} }
    }
    
    if (-not $GroupBy)
    {
        $inputData = $inputData | ForEach-Object $propertySelect
        trap { Write-Error $_ -Category 5 -EA 1 }
    }
    else
    {
        if ($GroupBy -is [hashtable])
        {
            $GroupBy.Keys | ForEach-Object {
                if     ($_ -match '^(na?m?e?|la?b?e?l?)$')     { $gLabel = $GroupBy.$_ }
                elseif ($_ -match '^ex?p?r?e?s?s?i?o?n?$')     { $gExpr = $GroupBy.$_ }
                elseif ($_ -match '^fo?r?m?a?t?s?t?r?i?n?g?$') { $gFormatStr = $GroupBy.$_ }
                else { Write-Error "Invalid GroupBy hash table key '${_}'." -Category 5 -EA 1 }
            }
            if ($gExpr)
            {
                if ($gLabel -and $gLabel -isnot [string]) { Write-Error "Invalid GroupBy name/label type." -Category 5 -EA 1 }
                if ($gFormatStr -and $gFormatStr -isnot [string]) { Write-Error "Invalid Property formatstring type." -Category 5 -EA 1 }
                
                if ($gExpr -is [string] -or $gExpr -is [scriptblock])
                {
                    if ($gFormatStr)
                    {
                        if ($gExpr -is [string]) { $groupSelect = {$gFormatStr -f $_.$gExpr} }
                        else                     { $groupSelect = [scriptblock]::Create("'${gFormatStr}' -f $gExpr") }
                    }
                    else
                    {
                        if ($gExpr -is [string]) { $groupSelect = {$_.$gExpr} }
                        else                     { $groupSelect = [scriptblock]::Create($gExpr) }
                    }
                    
                    if (-not $gLabel)
                    {
                        if ($gExpr -is [string])
                        {
                            if (-not ($groupLabel = $inputData[0].PSObject.Properties.Name.Where({$_ -eq $gExpr}))) { $groupLabel = $gExpr }
                        }
                        else { $groupLabel = $gExpr }
                    }
                    else { $groupLabel = $gLabel }
                }
                else { Write-Error "Invalid GroupBy expression type." -Category 5 -EA 1 }
            }
            else { Write-Error "GroupBy hash table is missing mandatory expression entry." -Category 5 -EA 1 }
        }
        elseif ($GroupBy -is [string])
        {
            $groupSelect = {$_.$GroupBy}
            if (-not ($groupLabel = $inputData[0].PSObject.Properties.Name.Where({$_ -eq $GroupBy}))) { $groupLabel = $GroupBy }
        }
        elseif ($GroupBy -is [scriptblock])
        {
            $groupSelect = [scriptblock]::Create($GroupBy)
            $groupLabel = $GroupBy
        }
        else { Write-Error "Invalid GroupBy type." -Category 5 -EA 1 }
        
        $inputData = $inputData | ForEach-Object {
            [pscustomobject]@{$propertySelect = & $propertySelect; $groupSelect = & $groupSelect}
        }
        trap { Write-Error $_ -Category 5 -EA 1 }
        
        $groupValues = ($inputData | Group-Object ([string]$groupSelect)).Name | Sort-Object
        $groupFilter = {[string]$_.$groupSelect -eq $groupValue}
        
        $inputDataGroups = [Collections.ArrayList]@()
        foreach ($groupValue in $groupValues)
        {
            [void]$inputDataGroups.Add(($inputData.Where($groupFilter).ForEach([string]$propertySelect)))
        }
    }
    
    # Output Processing
    
    if (-not $psISE) { $consoleWidth = $Host.UI.RawUI.WindowSize.Width }
    else             { $consoleWidth = $Host.UI.RawUI.BufferSize.Width }
    $columnGap = 1
    
    if (-not $inputDataGroups)
    {
        $maxLength = ($inputData | Measure-Object Length -Maximum).Maximum
        
        if (-not $ColumnCount)
        {
            $ColumnCount = [Math]::Max(1, [Math]::Floor($consoleWidth / ($maxLength + $columnGap)))
            
            if ($inputData.Count -lt $ColumnCount) { $ColumnCount = $inputData.Count }
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
        
        # Output data ordered column by column or row by row
        
        if ($PSEdition -eq 'Desktop') { Write-Output "`n" }
        else                          { Write-Output "" }
        if ($OrderBy -eq 'Column')
        {
            0..($rowCount - 1) | ForEach-Object {
                $row = $_
                $lineContent = 0..($ColumnCount - 1) | ForEach-Object {
                    $column = $_
                    @($inputData)[$row + $column * $rowCount]
                }
                Write-Output ($formatString -f $lineContent)
            }
        }
        else
        {
            0..($rowCount - 1) | ForEach-Object {
                $row = $_
                $lineContent = 0..($ColumnCount - 1) | ForEach-Object {
                    $column = $_
                    @($inputData)[$column + $row * $ColumnCount]
                }
                Write-Output ($formatString -f $lineContent)
            }
        }
        if ($PSEdition -eq 'Desktop') { Write-Output "`n" }
        else                          { Write-Output "" }
    }
    else
    {
        if (-not $ColumnCount)
        {
            $ColumnCount = ($inputDataGroups | ForEach-Object {
                $maxLength = ($_ | Measure-Object Length -Maximum).Maximum
                $colCount = [Math]::Max(1, [Math]::Floor($consoleWidth / ($maxLength + $columnGap)))
                
                if ($MaxColumnCount -and $MaxColumnCount -lt $colCount) { $MaxColumnCount }
                else                                                    { $colCount }
            } | Measure-Object -Minimum).Minimum
        }
        
        $i = 0
        foreach ($inputDataGroup in $inputDataGroups)
        {
            $rowCount = [Math]::Ceiling($inputDataGroup.Count / $ColumnCount)
            
            if ($MinRowCount -and $MinRowCount -gt $rowCount)
            {
                $ColumnCount = [Math]::Max(1, [Math]::Floor($inputDataGroup.Count / $MinRowCount))
                $rowCount = [Math]::Ceiling($inputDataGroup.Count / $ColumnCount)
            }
            
            $maxLength = ($inputDataGroup | Measure-Object Length -Maximum).Maximum
            $columnWidth = [Math]::Floor(($consoleWidth - $ColumnCount * $columnGap) / $ColumnCount)
            
            <# Truncate strings longer than column width (applicable only for CustomSize mode, or in
               AutoSize mode if string lengths greater than or equal to console width are present). #>
            if ($maxLength -gt $columnWidth)
            {
                if ($columnWidth -ge 3)
                {
                    $inputDataGroup = $inputDataGroup | ForEach-Object {
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
            
            # Output data ordered column by column or row by row, adding group label and value
            
            $groupValue = if (@($groupValues)[$i]) { @($groupValues)[$i] } else { '$null' }
            
            if ($PSEdition -eq 'Desktop') { Write-Output "" }
            Write-Output "`n   ${groupLabel}: ${groupValue}`n"
            if ($PSEdition -eq 'Desktop') { Write-Output "" }
            
            if ($OrderBy -eq 'Column')
            {
                0..($rowCount - 1) | ForEach-Object {
                    $row = $_
                    $lineContent = 0..($ColumnCount - 1) | ForEach-Object {
                        $column = $_
                        @($inputDataGroup)[$row + $column * $rowCount]
                    }
                    Write-Output ($formatString -f $lineContent)
                }
            }
            else
            {
                0..($rowCount - 1) | ForEach-Object {
                    $row = $_
                    $lineContent = 0..($ColumnCount - 1) | ForEach-Object {
                        $column = $_
                        @($inputDataGroup)[$column + $row * $ColumnCount]
                    }
                    Write-Output ($formatString -f $lineContent)
                }
            }
            if (++$i -eq $groupValues.Count)
            {
                if ($PSEdition -eq 'Desktop') { Write-Output "`n" }
                else                          { Write-Output "" }
            }
        }
    }
}
