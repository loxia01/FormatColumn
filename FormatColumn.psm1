using namespace System.Management.Automation

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
 Format-Column -Property @{FormatString='{0:000}'} -ColumnCount 3 -InputObject (1..125)

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
        [SupportsWildcards()]
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
        [SupportsWildcards()]
        [Object]$GroupBy,

        [Parameter()]
        [ValidateSet('Column','Row')]
        [string]$OrderBy = 'Column',

        [Parameter(ValueFromPipeline)]
        [psobject]$InputObject
    )
    if ($input) { $InputObject = $input }

    if ($null -eq $InputObject) { return }

    # Property and GroupBy validation and processing

    $properties = $InputObject[0].PSObject.Properties

    if ($Property)
    {
        if ($Property -is [hashtable])
        {
            $Property.Keys | ForEach-Object {
                if     ($_ -match '^e(x(p(r(e(s(s(i(on?)?)?)?)?)?)?)?)?$')         { $pExpr = $Property.$_ }
                elseif ($_ -match '^f(o(r(m(a(t(s(t(r(i(ng?)?)?)?)?)?)?)?)?)?)?$') { $pFormatStr = $Property.$_ }
                else
                {
                    $exception = New-Object PSArgumentException "Invalid key '${_}' in Property hashtable."
                    $PSCmdlet.ThrowTerminatingError((New-Object ErrorRecord -Args $exception, 'DictionaryKeyIllegal', 5, $null))
                }
            }
            if ($pFormatStr -and $pFormatStr -isnot [string])
            {
                $exception = New-Object PSArgumentException "Formatstring key in Property hashtable is not of type String."
                $PSCmdlet.ThrowTerminatingError((New-Object ErrorRecord -Args $exception, 'DictionaryKeyIllegalValue', 5, $null))
            }
            if ($pExpr)
            {
                if ($pExpr -is [string])
                {
                    if ([wildcardpattern]::ContainsWildcardCharacters($pExpr))
                    {
                        $pExpr = $properties | Where-Object Name -Like $pExpr | Select-Object -ExpandProperty Name -First 1
                    }
                    if ($pFormatStr) { $propertySelect = {$pFormatStr -f ($_.$pExpr -join ", ")} }
                    else             { $propertySelect = {$_.$pExpr -join ", "} }
                }
                elseif ($pExpr -is [scriptblock])
                {
                    $pExpr = [scriptblock]::Create("@(${pExpr}) -join ', '")
                    if ($pFormatStr) { $propertySelect = {$pFormatStr -f (& $pExpr)} }
                    else             { $propertySelect = $pExpr }
                }
                else
                {
                    $exception = New-Object PSArgumentException "Expression key in Property hashtable is not of type String or ScriptBlock."
                    $PSCmdlet.ThrowTerminatingError((New-Object ErrorRecord -Args $exception, 'DictionaryKeyIllegalValue', 5, $null))
                }
            }
            else
            {
                $exception = New-Object PSArgumentException "Property hashtable is missing mandatory expression key."
                $PSCmdlet.ThrowTerminatingError((New-Object ErrorRecord -Args $exception, 'DictionaryKeyMandatoryEntry', 5, $null))
            }
        }
        elseif ($Property -is [string])
        {
            if ([wildcardpattern]::ContainsWildcardCharacters($Property))
            {
                $Property = $properties | Where-Object Name -Like $Property | Select-Object -ExpandProperty Name -First 1
            }
            $propertySelect = {$_.$Property -join ", "}
        }
        elseif ($Property -is [scriptblock]) { $propertySelect = [scriptblock]::Create("@(${Property}) -join ', '") }
        else
        {
            $exception = New-Object PSArgumentException "Property parameter value is not of type String, ScriptBlock or Hashtable."
            $PSCmdlet.ThrowTerminatingError((New-Object ErrorRecord -Args $exception, 'ArgumentUnknownType', 5, $null))
        }
    }
    else
    {
        if ($InputObject[0].PSStandardMembers.DefaultDisplayPropertySet -or $InputObject[0].PSStandardMembers.DefaultDisplayProperty)
        {
            $defaultDisplayProperty =
                if ($InputObject[0].PSStandardMembers.DefaultDisplayPropertySet)
                {
                    if ($InputObject[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames -contains 'Name')
                    {
                        'Name'
                    }
                    elseif ($InputObject[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames -like '*Name')
                    {
                        $InputObject[0].PSStandardMembers.DefaultDisplayPropertySet | Where-Object ReferencedPropertyNames -Like '*Name' |
                            Select-Object -ExpandProperty ReferencedPropertyNames -First 1
                    }
                    else { $InputObject[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames[0] }
                }
                else { $InputObject[0].PSStandardMembers.DefaultDisplayProperty }

            $propertySelect = {$_.$defaultDisplayProperty -join ", "}
        }
        else
        {
            $displayProperty =
                if     ($properties.Name -contains 'Name') { 'Name' }
                elseif ($properties.Name -like '*Name')
                {
                    $properties | Where-Object Name -Like '*Name' | Select-Object -ExpandProperty Name -First 1
                }
                elseif (-not ($properties.Name -match '^(Count|Length)$')) { @($properties.Name)[0] }
                else { $false }

            if ($displayProperty) { $propertySelect = {$_.$displayProperty -join ", "} }
            else                  { $propertySelect = {$_ -join ", "} }
        }
    }

    if (-not $GroupBy)
    {
        $outputData = $InputObject | ForEach-Object $propertySelect
        trap { $PSCmdlet.ThrowTerminatingError($_) }
    }
    else
    {
        if ($GroupBy -is [hashtable])
        {
            $GroupBy.Keys | ForEach-Object {
                if     ($_ -match '^n(a(me?)?)?$|^l(a(b(el?)?)?)?$')               { $gLabel = $GroupBy.$_ }
                elseif ($_ -match '^e(x(p(r(e(s(s(i(on?)?)?)?)?)?)?)?)?$')         { $gExpr = $GroupBy.$_ }
                elseif ($_ -match '^f(o(r(m(a(t(s(t(r(i(ng?)?)?)?)?)?)?)?)?)?)?$') { $gFormatStr = $GroupBy.$_ }
                else
                {
                    $exception = New-Object PSArgumentException "Invalid key '${_}' in GroupBy hashtable."
                    $PSCmdlet.ThrowTerminatingError((New-Object ErrorRecord -Args $exception, 'DictionaryKeyIllegal', 5, $null))
                }
            }
            if ($gLabel -and $gLabel -isnot [string])
            {
                $exception = New-Object PSArgumentException "Label/Name key in GroupBy hashtable is not of type String."
                $PSCmdlet.ThrowTerminatingError((New-Object ErrorRecord -Args $exception, 'DictionaryKeyIllegalValue', 5, $null))
            }
            if ($gFormatStr -and $gFormatStr -isnot [string])
            {
                $exception = New-Object PSArgumentException "Formatstring key in GroupBy hashtable is not of type String."
                $PSCmdlet.ThrowTerminatingError((New-Object ErrorRecord -Args $exception, 'DictionaryKeyIllegalValue', 5, $null))
            }
            if ($gExpr)
            {
                if ($gExpr -is [string])
                {
                    $gExpr = $properties | Where-Object Name -Like $gExpr | Select-Object -ExpandProperty Name -First 1
                    if ($gFormatStr) { $groupSelect = {$gFormatStr -f ($_.$gExpr -join ", ")} }
                    else             { $groupSelect = {$_.$gExpr -join ", "} }
                }
                elseif ($gExpr -is [scriptblock])
                {
                    $gExpr = [scriptblock]::Create("@(${gExpr}) -join ', '")
                    if ($gFormatStr) { $groupSelect = {$gFormatStr -f (& $gExpr)} }
                    else             { $groupSelect = $gExpr }
                }
                else
                {
                    $exception = New-Object PSArgumentException "Expression key in GroupBy hashtable is not of type String or ScriptBlock."
                    $PSCmdlet.ThrowTerminatingError((New-Object ErrorRecord -Args $exception, 'DictionaryKeyIllegalValue', 5, $null))
                }
            }
            else
            {
                $exception = New-Object PSArgumentException "GroupBy hashtable is missing mandatory expression key."
                $PSCmdlet.ThrowTerminatingError((New-Object ErrorRecord -Args $exception, 'DictionaryKeyMandatoryEntry', 5, $null))
            }
        }
        elseif ($GroupBy -is [string])
        {
            $GroupBy = $properties | Where-Object Name -Like $GroupBy | Select-Object -ExpandProperty Name -First 1
            $groupSelect = {$_.$GroupBy -join ", "}
        }
        elseif ($GroupBy -is [scriptblock]) { $groupSelect = [scriptblock]::Create("@(${GroupBy}) -join ', '") }
        else
        {
            $exception = New-Object PSArgumentException "GroupBy parameter value is not of type String, ScriptBlock or Hashtable."
            $PSCmdlet.ThrowTerminatingError((New-Object ErrorRecord -Args $exception, 'ArgumentUnknownType', 5, $null))
        }

        if (-not $gLabel)
        {
            if ($gExpr) { $gLabel = $gExpr }
            else        { $gLabel = $GroupBy }
        }

        $outputData = $InputObject | ForEach-Object {
            [pscustomobject]@{$propertySelect = & $propertySelect; $groupSelect = & $groupSelect}
        }
        $groupValues = $outputData.$groupSelect | Sort-Object -Unique

        $outputDataGroups = [Collections.Generic.List[Object]]@()
        foreach ($groupValue in $groupValues)
        {
            $outputDataGroups.Add($outputData.Where({$_.$groupSelect -eq $groupValue}).$propertySelect)
        }

        trap { $PSCmdlet.ThrowTerminatingError($_) }
    }

    # Output Processing

    if (-not $psISE) { $consoleWidth = $Host.UI.RawUI.WindowSize.Width }
    else             { $consoleWidth = $Host.UI.RawUI.BufferSize.Width }
    $columnGap = 1

    if (-not $outputDataGroups)
    {
        $maxLength = ($outputData | Measure-Object Length -Maximum).Maximum

        if (-not $ColumnCount)
        {
            $ColumnCount = [Math]::Max(1, [Math]::Floor($consoleWidth / ($maxLength + $columnGap)))

            if ($outputData.Count -lt $ColumnCount) { $ColumnCount = $outputData.Count }
            if ($MaxColumnCount -and $MaxColumnCount -lt $ColumnCount) { $ColumnCount = $MaxColumnCount }
        }

        $rowCount = [Math]::Ceiling($outputData.Count / $ColumnCount)

        if ($MinRowCount -and $MinRowCount -gt $rowCount)
        {
            $ColumnCount = [Math]::Max(1, [Math]::Floor($outputData.Count / $MinRowCount))
            $rowCount = [Math]::Ceiling($outputData.Count / $ColumnCount)
        }

        $columnWidth = [Math]::Floor(($consoleWidth - $ColumnCount * $columnGap) / $ColumnCount)

        <# Truncate strings longer than column width (applicable only for CustomSize mode, or in
           AutoSize mode if string lengths greater than or equal to console width are present). #>
        if ($maxLength -gt $columnWidth)
        {
            if ($columnWidth -ge 3)
            {
                $outputData = $outputData | ForEach-Object {
                    if ($_.Length -gt $columnWidth) { $_.Remove($columnWidth - 3) + "..." }
                    else                            { $_ }
                }
            }
            # Write terminating error if column width is too small for truncate ellipsis "..."
            else
            {
                $exception = "ColumnCount value too large for output display."
                $PSCmdlet.ThrowTerminatingError((New-Object ErrorRecord -Args $exception, 'ColumnCountDisplayLimit', 5, $null))
            }
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
                    @($outputData)[$row + $column * $rowCount]
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
                    @($outputData)[$column + $row * $ColumnCount]
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
            $ColumnCount = ($outputDataGroups | ForEach-Object {
                $maxLength = ($_ | Measure-Object Length -Maximum).Maximum
                $colCount = [Math]::Max(1, [Math]::Floor($consoleWidth / ($maxLength + $columnGap)))

                if ($MaxColumnCount -and $MaxColumnCount -lt $colCount) { $MaxColumnCount }
                else                                                    { $colCount }
            } | Measure-Object -Minimum).Minimum
        }

        $i = 0
        foreach ($outputDataGroup in $outputDataGroups)
        {
            $rowCount = [Math]::Ceiling($outputDataGroup.Count / $ColumnCount)

            if ($MinRowCount -and $MinRowCount -gt $rowCount)
            {
                $ColumnCount = [Math]::Max(1, [Math]::Floor($outputDataGroup.Count / $MinRowCount))
                $rowCount = [Math]::Ceiling($outputDataGroup.Count / $ColumnCount)
            }

            $maxLength = ($outputDataGroup | Measure-Object Length -Maximum).Maximum
            $columnWidth = [Math]::Floor(($consoleWidth - $ColumnCount * $columnGap) / $ColumnCount)

            <# Truncate strings longer than column width (applicable only for CustomSize mode, or in
               AutoSize mode if string lengths greater than or equal to console width are present). #>
            if ($maxLength -gt $columnWidth)
            {
                if ($columnWidth -ge 3)
                {
                    $outputDataGroup = $outputDataGroup | ForEach-Object {
                        if ($_.Length -gt $columnWidth) { $_.Remove($columnWidth - 3) + "..." }
                        else                            { $_ }
                    }
                }
                # Write terminating error if column width is too small for truncate ellipsis "..."
                else
                {
                    $exception = "ColumnCount value too large for output display."
                    $PSCmdlet.ThrowTerminatingError((New-Object ErrorRecord -Args $exception, 'ColumnCountDisplayLimit', 5, $null))
                }
            }

            # Create format string for output
            $alignment = -($columnWidth + $columnGap)
            $formatString = (
                0..($ColumnCount - 1) | ForEach-Object {
                    "{${_},${alignment}}"
                }
            ) -join ""

            # Output data ordered column by column or row by row, adding group label and value

            if ($PSEdition -eq 'Desktop') { Write-Output "" }
            Write-Output "`n   ${gLabel}: $(@($groupValues)[$i])`n"
            if ($PSEdition -eq 'Desktop') { Write-Output "" }

            if ($OrderBy -eq 'Column')
            {
                0..($rowCount - 1) | ForEach-Object {
                    $row = $_
                    $lineContent = 0..($ColumnCount - 1) | ForEach-Object {
                        $column = $_
                        @($outputDataGroup)[$row + $column * $rowCount]
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
                        @($outputDataGroup)[$column + $row * $ColumnCount]
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
