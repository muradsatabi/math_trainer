#Requires -Version 7.0
# Reads only project copies of the diagrams.
[CmdletBinding()]
param([switch]$Check)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$planningRoot = Join-Path $projectRoot 'docs/planning'
$sourceFiles = @('graphs.drawio', 'логика приложения.drawio')
$inventories = @()
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# Полная опись исходных схем')
$lines.Add('')
$lines.Add('Автоматически получено из копий Draw.io в sources/. Обновление: pwsh -File tool/export_planning_diagrams.ps1. Не редактировать вручную. Это опись набросков, не опубликованный банк и не утверждённые зависимости.')
$lines.Add('')
function Get-PlainLabel([string]$Value) {
    $plain = [System.Net.WebUtility]::HtmlDecode($Value)
    $plain = $plain -replace '<br\s*/?>', ' / ' -replace '</div>', ' / ' -replace '<[^>]+>', ''
    return $plain.Trim()
}
function Get-TableText([string]$Value) {
    return ($Value -replace '\|', '\|' -replace '[\r\n]+', ' ')
}
foreach ($sourceFile in $sourceFiles) {
    $sourcePath = Join-Path $planningRoot "sources/$sourceFile"
    $settings = [System.Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $reader = [System.Xml.XmlReader]::Create($sourcePath, $settings)
    $xml = [System.Xml.XmlDocument]::new()
    $xml.XmlResolver = $null
    try { $xml.Load($reader) } finally { $reader.Dispose() }
    $pages = @()
    foreach ($diagram in $xml.SelectNodes('/mxfile/diagram')) {
        if ($null -eq $diagram.SelectSingleNode('mxGraphModel/root')) {
            throw "Unsupported compressed or missing graph model: $sourceFile"
        }
        $cells = @($diagram.SelectNodes('mxGraphModel/root/mxCell'))
        $cellIds = @{}
        $nodeIds = @{}
        $nodes = @()
        foreach ($cell in $cells) {
            $id = $cell.GetAttribute('id')
            if (!$id -or $cellIds.ContainsKey($id)) { throw "Missing or duplicate cell ID: $sourceFile / $id" }
            $cellIds[$id] = $true
            if ($cell.GetAttribute('vertex') -ne '1') { continue }
            $nodeIds[$id] = $true
            $nodes += [ordered]@{
                sourceCellId = $id
                label = Get-PlainLabel $cell.GetAttribute('value')
                rawValue = $cell.GetAttribute('value')
                parent = $cell.GetAttribute('parent')
                style = $cell.GetAttribute('style')
                geometryXml = $cell.SelectSingleNode('mxGeometry').OuterXml
            }
        }
        $edges = @()
        foreach ($cell in $cells) {
            if ($cell.GetAttribute('edge') -ne '1') { continue }
            $from = $cell.GetAttribute('source')
            $to = $cell.GetAttribute('target')
            $issues = @()
            if (!$from) { $issues += 'missing_source' }
            elseif (!$nodeIds.ContainsKey($from)) { $issues += 'unknown_source' }
            if (!$to) { $issues += 'missing_target' }
            elseif (!$nodeIds.ContainsKey($to)) { $issues += 'unknown_target' }
            $edges += [ordered]@{
                sourceCellId = $cell.GetAttribute('id')
                from = $(if ($from) { $from } else { $null })
                to = $(if ($to) { $to } else { $null })
                label = Get-PlainLabel $cell.GetAttribute('value')
                style = $cell.GetAttribute('style')
                geometryXml = $cell.SelectSingleNode('mxGeometry').OuterXml
                interpretation = 'unreviewed'
                endpointIssues = @($issues)
            }
        }
        $pages += [ordered]@{ sourcePageId = $diagram.GetAttribute('id'); name = $diagram.GetAttribute('name'); nodes = @($nodes); edges = @($edges) }
        $lines.Add("## $sourceFile — $($diagram.GetAttribute('name'))")
        $lines.Add('')
        $lines.Add("Узлов: $($nodes.Count). Линий: $($edges.Count). ID ниже — идентификаторы элементов Draw.io, не ID будущего банка.")
        $lines.Add('')
        $lines.Add('| ID узла | Надпись |')
        $lines.Add('| --- | --- |')
        foreach ($node in $nodes) { $lines.Add("| $($node.sourceCellId) | $(Get-TableText $node.label) |") }
        $lines.Add('')
        $lines.Add('| ID линии | От узла | К узлу | Проверка концов |')
        $lines.Add('| --- | --- | --- | --- |')
        foreach ($edge in $edges) {
            $fromLabel = @($nodes | Where-Object sourceCellId -eq $edge.from | ForEach-Object label) -join ''
            $toLabel = @($nodes | Where-Object sourceCellId -eq $edge.to | ForEach-Object label) -join ''
            $result = $(if ($edge.endpointIssues.Count) { $edge.endpointIssues -join ', ' } else { 'Оба узла существуют; смысл связи не утверждён' })
            $lines.Add("| $($edge.sourceCellId) | $(Get-TableText "$($edge.from) $fromLabel") | $(Get-TableText "$($edge.to) $toLabel") | $result |")
        }
        $lines.Add('')
    }
    $inventories += [ordered]@{ sourceFile = "sources/$sourceFile"; sourceSha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant(); pages = @($pages) }
}
$snapshot = [ordered]@{ formatVersion = 1; purpose = 'planning_inventory_not_runtime_bank'; diagrams = @($inventories) }
$outputs = [ordered]@{
    'diagram_inventory.json' = ($snapshot | ConvertTo-Json -Depth 30) + "`n"
    'diagram_inventory.md' = ($lines -join "`n") + "`n"
}
foreach ($fileName in $outputs.Keys) {
    $outputPath = Join-Path $planningRoot $fileName
    if ($Check) {
        if (!(Test-Path -LiteralPath $outputPath) -or [System.IO.File]::ReadAllText($outputPath) -cne $outputs[$fileName]) { throw "Inventory needs regeneration: $fileName" }
    } else {
        [System.IO.File]::WriteAllText($outputPath, $outputs[$fileName], [System.Text.UTF8Encoding]::new($false))
    }
}
Write-Output $(if ($Check) { 'Planning inventories match the source diagrams.' } else { 'Planning inventories regenerated.' })
