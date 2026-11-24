# SQL PRIME - SQL Server service helpers (Phase 0 extraction)

# Lista única de servicios SQL de la instancia (instalados o no). Get-Service
# se encarga de descartar los que no existen en este servidor.
function Get-SQLServiceCandidates {
    param([string]$Instance)

    $isDefault = ($Instance -ieq "MSSQLSERVER")
    $suffix = if ($isDefault) { "" } else { "`$$Instance" }
    # El motor con nombre se llama MSSQL$INST (no MSSQLSERVER$INST).
    $engine = if ($isDefault) { "MSSQLSERVER" } else { "MSSQL`$$Instance" }
    $agent  = if ($isDefault) { "SQLSERVERAGENT" } else { "SQLSERVERAGENT`$$Instance" }
    $filestream = if ($isDefault) { "MSSQLFDLauncher" } else { "MSSQLFDLauncher`$$Instance" }
    return @(
        $engine,
        $agent,
        $filestream,
        "SQLBrowser",
        "SQLWriter",
        "MSSQLServerOLAPService$suffix",
        "MSSQLServerOLAPService",
        "ReportServer$suffix",
        "ReportServer",
        "MsDtsServer100", "MsDtsServer110", "MsDtsServer120",
        "MsDtsServer130", "MsDtsServer140", "MsDtsServer150",
        "SQLServerIntegrationServices$suffix",
        "SQLServerDistributedReplayController",
        "SQLServerDistributedReplayClient"
    ) | Select-Object -Unique
}

# Una sola llamada a Get-Service para TODOS los candidatos: evita decenas de
# consultas al Service Control Manager y es la base del modo rápido.
function Get-SQLServiceStates {
    param([string]$Instance)
    $map = @{}
    foreach ($s in @(Get-Service -Name @(Get-SQLServiceCandidates -Instance $Instance) -ErrorAction SilentlyContinue)) {
        if ($null -ne $s -and $s.Name) { $map[$s.Name] = $s }
    }
    return $map
}
