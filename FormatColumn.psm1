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
#>
    
    [CmdletBinding(DefaultParameterSetName='AutoSize')]
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
        [ValidateSet('Column','Row')]
        [string]$OrderBy='Column',
        
        [Parameter(ValueFromPipeline)]
        [Object]$InputObject
    )
    if ($input) { $InputObject = $input }
    
    if ($InputObject -ne $null) { $inputData = $InputObject }
    else { return }
    
    # Property validation and processing, data conversion to string array.
    if ($Property -ne $null)
    {
        if ($Property -is [hashtable])
        {
            $Property.Keys | ForEach-Object {
                if     ($_ -match '^ex?p?r?e?s?s?i?o?n?$')     { $expression = $Property.$_ }
                elseif ($_ -match '^fo?r?m?a?t?s?t?r?i?n?g?$') { $formatString = $Property.$_ }
                else { Write-Error "Invalid Property key '${_}'." -Category 5 -EA 1 }
            }
            if ($expression)
            {
                if ($expression -is [string])
                {
                    $inputData = $inputData | ForEach-Object { $_.$expression }
                }
                elseif ($expression -is [scriptblock])
                {
                    $expression = $expression.ToString()
                    $inputData = $inputData | ForEach-Object { Invoke-Expression $expression }
                    trap { Write-Error "Expression processing error." -Category 5 -EA 1 }
                }
                else { Write-Error "Invalid Expression type." -Category 5 -EA 1 }
            }
            if ($formatString)
            {
                if ($formatString -is [string])
                {
                    $inputData = $inputData | ForEach-Object { $formatString -f $_ }
                    trap { Write-Error "FormatString processing error." -Category 5 -EA 1 }
                }
                else { Write-Error "Invalid FormatString type." -Category 5 -EA 1 }
            }
        }
        elseif ($Property -is [scriptblock])
        {
            $Property = $Property.ToString()
            $inputData = $inputData | ForEach-Object { Invoke-Expression $Property }
            trap { Write-Error "Property processing error." -Category 5 -EA 1 }
        }
        elseif ($Property -is [string])
        {
            $inputData = $inputData | ForEach-Object { $_.$Property }
        }
        else
        {
            try
            {
                $Property = $Property.ToString()
                $inputData = $inputData | ForEach-Object { $_.$Property }
            }
            catch { Write-Error "Invalid Property type." -Category 5 -EA 1 }
        }
        
        if ($inputData -ne $null) { $inputData = $inputData | ForEach-Object { [string]$_ } }
        else { return "`n" }
    }
    else
    {
        $defaultDisplayProperty =
            if ($inputData.PSStandardMembers.DefaultDisplayPropertySet)
            {
                $inputData.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames[-1]
            }
            elseif ($inputData.PSStandardMembers.DefaultDisplayProperty)
            {
                $inputData.PSStandardMembers.DefaultDisplayProperty
            }
            else { $null }
        if ($defaultDisplayProperty)
        {
            $inputData = $inputData | ForEach-Object { $_.$defaultDisplayProperty }
        }
        
        $inputData = $inputData | ForEach-Object { [string]$_ }
    }
    
    
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
    
    <# Truncate strings longer than column width (applicable only for CustomSize mode, or if
       string lengths ≥ console width are present in AutoSize mode). #>
    if ($maxLength -gt $columnWidth)
    {
        if ($columnWidth -ge 3)
        {
            $inputData = $inputData | ForEach-Object {
                if ($_.Length -gt $columnWidth) { $_.Remove($columnWidth - 3) + "..." }
                else { $_ }
            }
        }
        # Write terminating error if column width is too small for displaying truncate ellipsis "...".
        else { Write-Error "ColumnCount value too large for data to be displayed." -Category 5 -EA 1 }
    }
    
    # Create format string for output.
    $format = (1..$ColumnCount | ForEach-Object {
        $column = $_ - 1
        "{${column},$(-($columnWidth + $columnGap))}"
    }) -join ''
    
    # Output data ordered column by column or row by row.
    Write-Output "`n"
    Write-Output (
        1..$rowCount | ForEach-Object {
            $row = $_ - 1
            $lineContent = 1..$ColumnCount | ForEach-Object {
                $column = $_ - 1
                if ($OrderBy -eq 'Column') { @($inputData)[$row + $column * $rowCount] }
                if ($OrderBy -eq 'Row')    { @($inputData)[$column + $row * $ColumnCount] }
            }
            $format -f $lineContent
        }
    )
    Write-Output "`n"
}
