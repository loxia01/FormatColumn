Sub HideEmptyRows()
    
    StartRow = 3
    EndRow = 25
    ColNum = 2
    
    For i = StartRow To EndRow
        If Worksheets("Sheet1").Cells(i, ColNum).Value = "" Then
            Worksheets("Sheet1").Cells(i, ColNum).EntireRow.Hidden = True
        Else
            Worksheets("Sheet1").Cells(i, ColNum).EntireRow.Hidden = False
        End If
    Next i
    
End Sub
