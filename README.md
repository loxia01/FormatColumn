# FormatColumn
FormatColumn module contains the function Format-Column that formats object data as columns, ordering data column by column as default.
## Installation
The module can be downloaded from PowerShell Gallery using PowerShell command line:

`Install-Module -Name FormatColumn`

or manually downloaded here on GitHub:

Download the module files (extensions `.psm1` and `.psd1`) and then create a new module folder in your `PSModulePath`. Default `PSModulePath` is:

- for a specific user: `%UserProfile%\Documents\WindowsPowerShell\Modules\`
- for all users: `%ProgramFiles%\WindowsPowerShell\Modules\`

Name the new module folder exactly as the filename without extension, in this case `FormatColumn` and then copy the downloaded module file to that folder. PowerShell will now automatically find the module and its functions.
## Functions
### Format-Column
#### Syntax
```
Format-Column [[-Property] <Object>] [-MaxColumnCount <int>] [-MinRowCount <int>] [-OrderBy <string>] [-InputObject <Object>] [<CommonParameters>]

Format-Column [[-Property] <Object>] -ColumnCount <int> [-OrderBy <string>] [-InputObject <Object>] [<CommonParameters>]
```
#### Description
Format-Column outputs object data into columns, similarly to built-in cmdlet Format-Wide. It can order output data column by column in addition to row by row, as is the only option in Format-Wide. Format-Column also performs some initial input data processing which makes it easy to input objects without properties e.g. plain arrays.
#### Parameters
##### Property
Name of object property to be displayed.
 
The value of the Property parameter can also be a calculated property:
- a hash table in the form of:
    - `@{Expression=<string>|{<scriptblock>}}`
    - `@{FormatString=<string>}`
    - `@{Expression=<string>|{<scriptblock>}; FormatString=<string>}`
- a script block: `{<scriptblock>}`
 
Property parameter is optional. However, if omitted for data containing properties, but missing DefaultDisplayProperty, no comprehensible data output will be produced.
##### ColumnCount
Number of columns to display (CustomSize mode). If ColumnCount parameter is omitted the number of columns is calculated automatically (AutoSize mode).
##### MaxColumnCount
Maximum number of columns to display in AutoSize mode. Optional. Cannot be combined with ColumnCount parameter.
##### MinRowCount
Minimum number of rows to display in AutoSize mode. Optional. Cannot be combined with ColumnCount parameter.
##### OrderBy
Determines data order in column output. Default value is Column.

Valid values are:
- Column: Orders data column by column.
- Row: Orders data row by row.
##### InputObject
Object to format for display. Accepts pipeline input.
#### Usage examples
##### Example 1
`1..100 | Format-Column -MinRowCount 20 -OrderBy Row`
##### Example 2 
`Format-Column -Property @{FormatString='{0:000}'} -ColumnCount 3 -InputObject @(1..125)`
##### Example 3
`Get-Process | Format-Column -Property @{Expr='Id'; FormatStr='{0:00000}'}`
##### Example 4
The following Property syntaxes are all equivalent:
- name (string):
    - `Get-Process | Format-Column -Property ProcessName`
- scriptblock:
    - `Get-Process | Format-Column -Property {$_.ProcessName}`
- hashtable string expression:
    - `Get-Process | Format-Column -Property @{Expr='ProcessName'}`
- hashtable scriptblock expression:
    - `Get-Process | Format-Column -Property @{Expr={$_.ProcessName}}`
