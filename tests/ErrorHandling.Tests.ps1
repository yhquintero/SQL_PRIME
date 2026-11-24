#Requires -Modules Pester
Describe 'ErrorHandling module' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\modules\ErrorHandling.ps1')
    }

    It 'creates operation ids as GUIDs' {
        $id = New-SQLPrimeOperationId
        { [guid]$id } | Should -Not -Throw
    }

    It 'returns standard error record' {
        $err = New-SQLPrimeErrorRecord -Code 'DOWNLOAD_FAILED' -Message 'boom' -Component 'download' -OperationId 'op1'
        $err.ok | Should -BeFalse
        $err.code | Should -Be 'DOWNLOAD_FAILED'
        $err.component | Should -Be 'download'
        $err.operationId | Should -Be 'op1'
    }

    It 'Invoke-SQLPrimeSafe captures exceptions' {
        $r = Invoke-SQLPrimeSafe -Code 'TEST_FAIL' -Component 'test' -OperationId 'op2' -Script { throw 'x' }
        $r.ok | Should -BeFalse
        $r.code | Should -Be 'TEST_FAIL'
    }
}
