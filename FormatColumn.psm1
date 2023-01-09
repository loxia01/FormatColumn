function Format-Column
{
<#
.SYNOPSIS
 Format-Column formats object data as columns, ordering data column by column as default.
 
.DESCRIPTION
 Format-Column function outputs object data into columns, similarly to built-in cmdlet Format-Wide.
 It can order output data column by column in addition to row by row,
 as is the only option in Format-Wide. Format-Column also performs some initial input data
 processing which makes it easy to input objects without properties e.g. plain arrays.
 
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
        
        [ValidateSet('Column','Row')]
        [string]$OrderBy='Column',
        
        [Parameter(ValueFromPipeline)]
        [Object]$InputObject
    )
    if ($input) { $InputObject = $input }
    
    if ($null -ne $InputObject) { $inputData = $InputObject }
    else { return }
    
    # Property validation and processing, data conversion to string array.
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
                    $inputData = $inputData | ForEach-Object { & ([scriptblock]::Create($expr)) }
                    trap { Write-Error "Expression processing error." -Category 5 -EA 1 }
                }
                else { Write-Error "Invalid Expression type." -Category 5 -EA 1 }
            }
            if ($formatStr)
            {
                if ($formatStr -is [string])
                {
                    $inputData = $inputData | ForEach-Object { $formatStr -f $_ }
                    trap { Write-Error "FormatString processing error." -Category 5 -EA 1 }
                }
                else { Write-Error "Invalid FormatString type." -Category 5 -EA 1 }
            }
        }
        elseif ($Property -is [scriptblock])
        {
            $inputData = $inputData | ForEach-Object { & ([scriptblock]::Create($Property)) }
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
        if ($inputData | Get-Member -MemberType Properties)
        {
            $defaultDisplayProperty =
                if ($inputData.PSStandardMembers.DefaultDisplayPropertySet -ne $null)
                {
                    $inputData.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames[-1]
                }
                elseif ($inputData.PSStandardMembers.DefaultDisplayProperty -ne $null)
                {
                    $inputData.PSStandardMembers.DefaultDisplayProperty[-1]
                }
                else { $null }
            
            if ($defaultDisplayProperty)
            {
                $inputData = $inputData | ForEach-Object { $_.$defaultDisplayProperty }
            }
        }
    }
    $inputData = $inputData | ForEach-Object { [string]$_ }
    
    
    $consoleWidth = $Host.UI.RawUI.WindowSize.Width
    $columnGap = 1
    
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
        # Write terminating error if column width is too small for truncate ellipsis "...".
        else { Write-Error "ColumnCount value too large for output display." -Category 5 -EA 1 }
    }
    
    # Create format string for output.
    $alignment = -($columnWidth + $columnGap)
    $formatString = (
        0..($ColumnCount - 1) | ForEach-Object {
            "{${_},${alignment}}"
        }
    ) -join ""
    
    # Output data ordered column by column or row by row, adding blank line(s) at top and bottom.
    if ($PSEdition -eq 'Desktop') { Write-Output "","" }
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
    if ($PSEdition -eq 'Desktop') { Write-Output "","" }
    else                          { Write-Output "" }
}
