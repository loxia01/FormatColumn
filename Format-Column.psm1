function Format-Column {
<#
.SYNOPSIS
 Format-Column function formats input data to columns.
 
.DESCRIPTION
 Format-Column outputs data into columns, like the built-in cmdlet Format-Wide.
 It can order output data column by column in addition to row by row,
 as is the only option in Format-Wide. Format-Column also performs some initial input data
 processing which makes it easy to input objects without named properties e.g. plain arrays.
 
.PARAMETER Property
 Name of object property to be displayed.
 The value of the Property parameter can also be a calculated property:
    - a hashtable in the form of:
        - 'Expression' = <string>|<scriptblock>
        - 'Expression' = <string>|<scriptblock> and 'FormatString' = <string>
    - a scriptblock
 
 Property parameter is optional. However, if omitted for objects with named properties,
 no meaningful data output will be produced.
 
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
 Determines data order in column output. Valid values are:
    - Column: Orders data by column.
    - Row: Orders data by row.
 
 Default is 'Column'. 
 
.PARAMETER InputObject
 Input data to display. Accepts pipeline input.
 
.EXAMPLE
 1..150 | Format-Column -OrderBy Row
 
.EXAMPLE
 Format-Column -ColumnCount 3 -InputObject @(1..130)
 
.EXAMPLE
 Get-Process | Format-Column -Property @{Expression='Handles'; FormatString='{0:00000}'} -MinRowCount 15
 
.EXAMPLE
 # These property syntaxes are all equivalent:
 PS C:\>Get-Process | Format-Column -Property ProcessName                    # name
 PS C:\>Get-Process | Format-Column -Property {$_.ProcessName}               # scriptblock
 PS C:\>Get-Process | Format-Column -Property @{Expression='ProcessName'}    # hashtable string expression
 PS C:\>Get-Process | Format-Column -Property @{Expression={$_.ProcessName}} # hashtable scriptblock expression
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
        
        [ValidateSet('Column','Row')]
        [String]$OrderBy='Column',
        
        [Parameter(ValueFromPipeline)]
        [PSObject]$InputObject
    )
    if ($input) { $InputObject = $input }
    
    if ($InputObject.Count -gt 0) { $inputData = $InputObject }
    else { return $InputObject}
    
    # Property input processing and data conversion to string array.
    if ($Property) {
        if ($Property -is [Hashtable]) {
            $expression = $Property.Expression
            if ($expression) {
                if ($expression -is [String]) {
                    $inputData = $inputData | ForEach-Object { $_.$expression }
                }
                elseif ($expression -is [ScriptBlock]) {
                    $expression = [ScriptBlock]::Create($expression)
                    $inputData = $inputData | ForEach-Object {
                        try { & $expression }
                        catch { Write-Error "Error when processing 'Property' input." -Category 5 -EA 1 }
                    }
                }
                else { Write-Error "Invalid 'Expression' key type." -Category 5 -EA 1 }
            }
            if ($Property.FormatString) {
                if ($Property.FormatString -is [String]) {
                    $inputData = $inputData | ForEach-Object { $Property.FormatString -f $_ }
                }
                else { Write-Error "Invalid 'FormatString' key type." -Category 5 -EA 1 }
            }
        }
        elseif ($Property -is [ScriptBlock]) {
            $Property = [ScriptBlock]::Create($Property)
            $inputData = $inputData | ForEach-Object {
                try { & $Property }
                catch { Write-Error "Error when processing 'Property' input." -Category 5 -EA 1 }
            }
        }
        elseif ($Property -is [String]) {
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
        $ColumnCount = [Math]::Max(1, ([Math]::Floor($consoleWidth / ($maxLength + $gutterWidth))))
        if ($inputData.Count -lt $ColumnCount) { $ColumnCount = $inputData.Count }
        
        if ($MaxColumnCount -and ($MaxColumnCount -lt $ColumnCount)) { $ColumnCount = $MaxColumnCount }
    }
    
    $rowCount = [Math]::Ceiling($inputData.Count / $ColumnCount)
    
    if ($MinRowCount -and ($MinRowCount -gt $rowCount)) {
        $ColumnCount = [Math]::Max(1, ([Math]::Floor($inputData.Count / $MinRowCount)))
        $rowCount = [Math]::Ceiling($inputData.Count / $ColumnCount)
    }
    
    $columnWidth = [Math]::Floor(($consoleWidth - $ColumnCount * $gutterWidth) / $ColumnCount)
    
    # Truncate strings longer than column width (applicable only for CustomSize mode, or if
    # extremely long strings (≥ console width) are present in AutoSize mode).
    if ($maxLength -gt $columnWidth) {
        if ($columnWidth -ge 3) {
            $inputData = $inputData | ForEach-Object {
                if ($_.Length -gt $columnWidth) { "$($_.Remove($columnWidth - 3))..." }
                else { $_ }
            }
        }
        # Write terminating error if column width is too small for displaying truncate symbol "...".
        if ($columnWidth -lt 3) {
            Write-Error "ColumnCount value is too large for data to be displayed." -Category 5 -EA 1
        }
    }
    
    # Create format string for output.
    $formatString = (1..$ColumnCount | ForEach-Object {
        $column = $_ - 1
        "{0}${column},$(-($columnWidth + $gutterWidth)){1}" -f '{','}'
    }) -join ''
    
    # Output data ordered by column or by row.
    Write-Output "`n"
    1..$rowCount | ForEach-Object {
        $row = $_ - 1
        $lineContent = 1..$ColumnCount | ForEach-Object {
            $column = $_ - 1
            if ($OrderBy -eq 'Column') { @($inputData)[$row + $column * $rowCount] }
            if ($OrderBy -eq 'Row') { @($inputData)[$column + $row * $ColumnCount] }
        }
        Write-Output ($formatString -f $lineContent)
    }
    Write-Output "`n"
}
