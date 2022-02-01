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
     - @{Expression=<string>|{<scriptblock>};FormatString=<string>}
     
 - a script block: {<scriptblock>}
 
 Property parameter is optional. However, if omitted for objects with properties,
 no comprehensible data output will be produced.
 
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
 Get-Process | Format-Column -Property @{Expr='Id';FormatStr='{0:00000}'}
 
.EXAMPLE
 # The following Property syntaxes are all equivalent:
 
 Get-Process | Format-Column -Property ProcessName              # name (string)
 Get-Process | Format-Column -Property {$_.ProcessName}         # scriptblock
 Get-Process | Format-Column -Property @{Expr='ProcessName'}    # hashtable string expression
 Get-Process | Format-Column -Property @{Expr={$_.ProcessName}} # hashtable scriptblock expression
#>
    
    [CmdletBinding(DefaultParameterSetName='AutoSize')]
    param(
        [Parameter(Position=0)]
        [Object]$Property,
        
        [Parameter(ParameterSetName='CustomSize', Mandatory)]
        [ValidateScript({$_ -gt 0})]
        [Int]$ColumnCount,
        
        [Parameter(ParameterSetName='AutoSize')]
        [ValidateScript({$_ -gt 0})]
        [Int]$MaxColumnCount,
        
        [Parameter(ParameterSetName='AutoSize')]
        [ValidateScript({$_ -gt 0})]
        [Int]$MinRowCount,
        
        [Parameter()]
        [ValidateSet('Column','Row')]
        [String]$OrderBy='Column',
        
        [Parameter(ValueFromPipeline)]
        [PSObject]$InputObject
    )
    if ($input) { $InputObject = $input }
    if ($InputObject.Count -gt 0) { $inputData = $InputObject }
    else { return $InputObject }
    
    # Property validation and processing, data conversion to string array.
    if ($Property)
    {
        if ($Property -is [Hashtable])
        {
            $Property.Keys | ForEach-Object {
                if ($_ -match '^ex?p?r?e?s?s?i?o?n?$') { $expression = $Property.$_ }
                elseif ($_ -match '^fo?r?m?a?t?s?t?r?i?n?g?$') { $formatString = $Property.$_ }
                else { Write-Error "Property key $_ not valid." -Category 5 -EA 1 }
            }
            if ($expression)
            {
                if ($expression -is [String])
                {
                    $inputData = $inputData | ForEach-Object { $_.$expression }
                }
                elseif ($expression -is [ScriptBlock])
                {
                    $expression = [ScriptBlock]::Create($expression)
                    $inputData = $inputData | ForEach-Object { & $expression }
                    trap { Write-Error "Expression processing error." -Category 5 -EA 1 }
                }
                else { Write-Error "Expression type not valid." -Category 5 -EA 1 }
            }
            if ($formatString)
            {
                if ($formatString -is [String])
                {
                    $inputData = $inputData | ForEach-Object { $formatString -f $_ }
                    trap { Write-Error "FormatString processing error." -Category 5 -EA 1 }
                }
                else { Write-Error "FormatString type not valid." -Category 5 -EA 1 }
            }
        }
        elseif ($Property -is [ScriptBlock])
        {
            $Property = [ScriptBlock]::Create($Property)
            $inputData = $inputData | ForEach-Object { & $Property }
            trap { Write-Error "Property processing error." -Category 5 -EA 1 }
        }
        elseif ($Property -is [String])
        {
            $inputData = $inputData | ForEach-Object { $_.$Property }
        }
        
        if ($inputData) { $inputData = $inputData | ForEach-Object { "$_" } }
        else { return }
    }
    else { $inputData = $inputData | ForEach-Object { "$_" } }
    
    
    $consoleWidth = $Host.UI.RawUI.WindowSize.Width
    $gutterWidth = 1
    
    $maxLength = ($inputData | Measure-Object Length -Maximum).Maximum
    
    if (! $ColumnCount) {
        $ColumnCount = [Math]::Max(1, [Math]::Floor($consoleWidth / ($maxLength + $gutterWidth)))
        if ($inputData.Count -lt $ColumnCount) { $ColumnCount = $inputData.Count }
        
        if ($MaxColumnCount -and $MaxColumnCount -lt $ColumnCount) { $ColumnCount = $MaxColumnCount }
    }
    
    $rowCount = [Math]::Ceiling($inputData.Count / $ColumnCount)
    
    if ($MinRowCount -and $MinRowCount -gt $rowCount) {
        $ColumnCount = [Math]::Max(1, [Math]::Floor($inputData.Count / $MinRowCount))
        $rowCount = [Math]::Ceiling($inputData.Count / $ColumnCount)
    }
    
    $columnWidth = [Math]::Floor(($consoleWidth - $ColumnCount * $gutterWidth) / $ColumnCount)
    
    <# Truncate strings longer than column width (applicable only for CustomSize mode, or if
       string lengths ≥ console width are present in AutoSize mode). #>
    if ($maxLength -gt $columnWidth) {
        if ($columnWidth -ge 3) {
            $inputData = $inputData | ForEach-Object {
                if ($_.Length -gt $columnWidth) { "$($_.Remove($columnWidth - 3))..." }
                else { $_ }
            }
        }
        # Write terminating error if column width is too small for displaying truncate ellipsis "...".
        else { Write-Error "ColumnCount value too large for data to be displayed." -Category 5 -EA 1 }
    }
    
    # Create format string for output.
    $format = (1..$ColumnCount | ForEach-Object {
        $column = $_ - 1
        "{${column},$(-($columnWidth + $gutterWidth))}"
    }) -join ''
    
    # Output data ordered column by column or row by row.
    Write-Output "`n", (
        1..$rowCount | ForEach-Object {
            $row = $_ - 1
            $lineContent = 1..$ColumnCount | ForEach-Object {
                $column = $_ - 1
                if ($OrderBy -eq 'Column') { @($inputData)[$row + $column * $rowCount] }
                if ($OrderBy -eq 'Row')    { @($inputData)[$column + $row * $ColumnCount] }
            }
            $format -f $lineContent
        }
    ), "`n"
}
