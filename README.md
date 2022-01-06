# PSFormatColumn
PSFormatColumn module contains the function Format-Column that formats input object data as columns.
## Installation
Download the module file (`.psm1`) and then create a new module folder in your `PSModulePath`. Default `PSModulePath` is:

- for a specific user: `$Env:UserProfile\Documents\WindowsPowerShell\Modules\`
- for all users: `$Env:ProgramFiles\WindowsPowerShell\Modules\`

Name the new module folder exactly as the `.psm1` file, in this case `PSFormatColumn` and then copy the downloaded module file to that folder. PowerShell will now automatically find the module and its functions.
## Functions
### Format-Column
#### Syntax
```
Format-Column [[-Property] <Object>] [-MaxColumnCount <int>] [-MinRowCount <int>] [-OrderBy <string>]
    [-InputObject <psobject>] [<CommonParameters>]
```
```
Format-Column [[-Property] <Object>] -ColumnCount <int> [-OrderBy <string>] [-InputObject <psobject>] [<CommonParameters>]
```
#### Description
Format-Column outputs object data into columns, similarly to built-in cmdlet Format-Wide. It can order output data column by column in addition to row by row, as is the only option in Format-Wide. Format-Column also performs some initial input data processing which makes it easy to input objects without properties e.g. plain arrays.
#### Parameters
##### Property
Name of object property to be displayed.
 
The value of the Property parameter can also be a calculated property:
- a hash table in the form of:
    - `@{Expression = <string>|{<scriptblock>}}`
    - `@{Expression = <string>|{<scriptblock>}; FormatString = <string>}`
- a script block: `{<scriptblock>}`
 
Property parameter is optional. However, if omitted for objects with properties, no comprehensible data output will be produced.
##### ColumnCount
Number of columns to display (CustomSize mode). If ColumnCount parameter is omitted the number of columns is calculated automatically (AutoSize mode).
##### MaxColumnCount
Maximum number of columns to display in AutoSize mode. Optional. Cannot be combined with ColumnCount parameter.
##### MinRowCount
Minimum number of rows to display in AutoSize mode. Optional. Cannot be combined with ColumnCount parameter.
##### OrderBy
Determines data order in column output. Default value is Column.

Valid values are:
- Column: Orders data by column.
- Row: Orders data by row.
##### InputObject
Object to format for display. Accepts pipeline input.
#### Usage examples
##### Example 1
`1..150 | Format-Column -OrderBy Row`
##### Example 2 
`Format-Column -ColumnCount 3 -InputObject @(1..130)`
##### Example 3
`Get-Process | Format-Column -Property @{Expression='Handles'; FormatString='{0:00000}'} -MinRowCount 15`
##### Example 4
The following Property syntaxes are all equivalent:
- name (string)&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; : `Get-Process | Format-Column -Property ProcessName`
- scriptblock&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; : `Get-Process | Format-Column -Property {$_.ProcessName}`
- hashtable string expression&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; : `Get-Process | Format-Column -Property @{Expression='ProcessName'}`
- hashtable scriptblock expression&nbsp;: `Get-Process | Format-Column -Property @{Expression={$_.ProcessName}}`
